# Internet Map — Implementation Plan

## Overview

A feature within an existing Rails app that lets workshop participants (scouts and
instructors, both existing `User` records) submit raw `traceroute`/`tracert` output for a
target domain. A background job parses the output, deduplicates hops into shared
`NetworkNode` records, enriches public IPs with ASN/organization data from a local
MaxMind-format database, and broadcasts incremental updates to a live
`cytoscape.js` graph via Turbo Streams. Multiple `InternetMap`s can exist per `Workshop`.

Stack constraints: Rails app, SQLite (no array/jsonb columns — use serialized JSON
`text` columns), SolidQueue for background jobs, Turbo Streams for live updates.

---

## 1. Data Model

```ruby
# Existing models, associations added:
# Workshop has_many :internet_maps
# User has_many :traceroutes

class InternetMap < ApplicationRecord
  belongs_to :workshop
  has_many :network_nodes, dependent: :destroy
  has_many :traceroutes, dependent: :destroy
end

class Traceroute < ApplicationRecord
  belongs_to :user
  belongs_to :internet_map
  has_many :network_nodes, dependent: :destroy
  has_many :network_links, dependent: :destroy

  enum :status, { pending: 0, processing: 1, complete: 2, failed: 3 }
  # columns: target_domain (string), raw_output (text), status (integer),
  #          error_message (text, nullable)
end

class NetworkNode < ApplicationRecord
  belongs_to :internet_map
  belongs_to :traceroute
  belongs_to :user            # denormalized from traceroute.user, used for dedupe key
  belongs_to :organization, optional: true

  # columns: ip_address (string), hostname (string, nullable), is_private (boolean),
  #          dedupe_key (string, indexed)

  validates :dedupe_key, uniqueness: { scope: :internet_map_id }
end

class NetworkLink < ApplicationRecord
  belongs_to :traceroute
  belongs_to :start_node, class_name: "NetworkNode"
  belongs_to :end_node, class_name: "NetworkNode"

  # columns: hop_number (integer), rtt_samples (text, serialized JSON array of floats/nil),
  #          timed_out (boolean, default: false)

  serialize :rtt_samples, coder: JSON
end

class Organization < ApplicationRecord
  has_many :network_nodes

  # columns: asn (integer, nullable, unique index), name (string), org_domain (string, nullable),
  #          color (string, hex), seeded (boolean, default: false)
end
```

### Dedupe key logic (critical piece — put this in a service, not inline)

`app/services/network_node_dedupe_key.rb`:

- **Public IP:** `"public:#{internet_map_id}:#{ip_address}"` — same public IP anywhere in
  the workshop resolves to the same node, so paths visibly converge across scouts.
- **Private/reserved IP:** `"private:#{internet_map_id}:#{user_id}:#{ip_address}"` — a
  scout's home router stays the same node across their own multiple traceroute
  submissions, but never collides with another scout's `192.168.1.1`.

`NetworkNode` creation should always go through a `find_or_create_by(dedupe_key:, internet_map_id:)`
in the enrichment job, not a plain `create`.

### IP classification

`app/services/ip_classifier.rb` — wraps `IPAddr#private?` plus explicit handling for:
- RFC1918 (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`)
- Loopback / link-local
- CGNAT (`100.64.0.0/10`) — not covered by stdlib `private?`, common on cellular/some ISPs
- IPv6 equivalents (`fc00::/7` ULA, `fe80::/10` link-local) if you want to support IPv6
  traceroutes at all — flag this as a decision point, see Open Questions.

Anything classified private/reserved short-circuits the ASN lookup entirely and gets a
fixed label (e.g. hostname `"Local Network"`) and no `Organization`.

---

## 2. Parser

`app/services/traceroute_parser.rb` — input: raw pasted text + target domain. Output: an
ordered array of hop structs: `{ position:, ip:, hostname:, rtt_samples: [Float, nil, ...], timed_out: }`.

Don't attempt one universal regex. Detect format first, then dispatch:

- **Unix-style** (macOS/Linux `traceroute`):
  `" 1  192.168.1.1 (192.168.1.1)  1.234 ms  1.111 ms  0.998 ms"`
- **Windows `tracert`**: different column spacing, `ms` without parens, often missing
  reverse DNS, uses `<1 ms` for sub-millisecond.
- **Timeout rows**: `* * *` (Unix) or `Request timed out.` (Windows) → `timed_out: true`,
  no node created for that hop, but keep the hop_number gap so the chain can potentially
  reconnect at the next successful hop (link from last successful node, skipping the gap).

Write this test-first with real sample output from both platforms — ambiguous/malformed
paste is the single most likely failure point. Store `raw_output` regardless of parse
success so failed parses are debuggable/reprocessable.

---

## 3. Background Job Flow (SolidQueue)

`ProcessTracerouteJob`:

1. Set `traceroute.status = :processing`.
2. Parse `raw_output` → array of hop structs.
3. For each hop:
   - Classify IP (public/private) via `IpClassifier`.
   - Build dedupe key via `NetworkNodeDedupeKey`.
   - `find_or_create_by(dedupe_key:, internet_map_id:)` for the `NetworkNode`.
   - If newly created and public → enqueue/perform ASN enrichment (see §4). If private →
     skip enrichment, assign generic label.
4. Create a synthetic "origin" node representing the scout's machine (hop 0) if not
   already present for this traceroute, so hop 1 has a link source.
5. Build `NetworkLink` records connecting consecutive successful nodes in order,
   carrying `rtt_samples` and `hop_number`. For timeout gaps, link across the gap
   (last successful node → next successful node) and consider flagging the link as
   `spans_gap: true` if you want the frontend to render it as dashed.
6. Set `traceroute.status = :complete` (or `:failed` with `error_message` set, inside a
   rescue block — don't let a malformed paste crash the job silently).
7. Broadcast via Turbo Stream (see §5).

Keep parsing and enrichment as separate private methods (or separate jobs chained via
`perform_later`) so a slow/failing ASN lookup doesn't block re-parsing later if you tune
the parser.

---

## 4. ASN/Organization Enrichment

**Data source:** IPLocate.io free MMDB database (IP → ASN), MaxMind-format, read via the
`maxmind-db` gem. No API calls, no rate limits — appropriate for a live nationwide Zoom
class submitting concurrently.

- Vendor the `.mmdb` file under e.g. `db/geoip/ip_to_asn.mmdb`, gitignored, fetched via a
  rake task (`rake geoip:update`) that downloads the latest file. Run on deploy and
  periodically (e.g. weekly) — not on every request.
- `app/services/asn_lookup.rb` wraps `MaxMind::DB.new(Rails.root.join("db/geoip/ip_to_asn.mmdb"))`,
  returns `{ asn:, org_name:, org_domain: }` or `nil` if unresolvable.
- Attribution requirement (CC BY-SA 4.0): add a small credit line — "IP data via
  IPLocate.io" — in the map view footer.

**Organization resolution**, in the enrichment step:

```ruby
org = Organization.find_or_create_by(asn: lookup[:asn]) do |o|
  o.name = lookup[:org_name]
  o.org_domain = lookup[:org_domain]
  o.seeded = false
  o.color = ColorAssigner.next_color_for(existing: Organization.pluck(:color))
end
node.update(organization: org)
```

`app/services/color_assigner.rb` — palette of ~24 curated, visually-distinct hex colors;
picks the first unused one, falls back to deterministic HSL generation (hash ASN → hue)
once the palette is exhausted, so colors never collide even at scale.

**Seed data** (`db/seeds.rb` or a dedicated `db/seeds/organizations.rb`): pre-populate
`Organization` rows with `seeded: true` and fixed colors for predictable heavy hitters —
Cloudflare, Google, Amazon/AWS, Microsoft, Meta, and major US residential ISPs (Comcast,
AT&T, Verizon, Spectrum/Charter, T-Mobile) since a nationwide scout cohort will surface
these constantly. `find_or_create_by(asn:)` in the enrichment step means seeded rows are
simply reused, never duplicated.

---

## 5. Live Updates

Use Turbo Streams (no need for raw ActionCable given this is a straightforward
broadcast-on-completion pattern):

- `InternetMap` broadcasts to a stream named e.g. `"internet_map_#{id}"`.
- On job completion, broadcast an `append`/custom stream action carrying the new
  `NetworkNode`/`NetworkLink` records (serialized to the JSON shape cytoscape expects —
  see §6) rather than re-rendering the whole page.
- Frontend: a Stimulus controller subscribed to the Turbo Stream receives the payload and
  calls `cy.add(...)` incrementally.
- **Layout:** do not re-run a full force-directed layout on every single incoming
  traceroute — jarring with a live audience. Either (a) run layout only on the newly
  added elements (`cy.layout({ eles: newEles, ... })` with a layout that respects
  existing positions), or (b) debounce and re-layout every N submissions / every few
  seconds instead of per-event. Recommend starting with (a).

---

## 6. Frontend (cytoscape.js + Stimulus)

- Node style: `background-color` mapped from `organization.color` (precomputed
  server-side, just pass through — no client-side hashing needed). Private/local nodes
  get a fixed neutral gray regardless of organization (there won't be one).
- Node label: hostname if present, else IP.
- Edge style: label or tooltip showing RTT; consider dashed styling for links that span
  a timeout gap.
- Tooltip/click-through on node: show organization name, ASN, and which scout(s)/
  traceroute(s) pass through this node (useful "look how many of us go through this one
  Cloudflare PoP" moment).
- Legend: derive from distinct `Organization` records currently present on the map
  (color swatch + name), regenerate as new orgs appear.

---

## 7. Submission Form

Simple form on the `InternetMap` show page (or a dedicated new/create route):
- `target_domain` text field
- `raw_output` textarea
- Brief instructional copy: `traceroute google.com` (Mac/Linux) or `tracert google.com`
  (Windows), paste the full output including the timing columns.
- On submit: create `Traceroute` with `status: pending`, enqueue `ProcessTracerouteJob`,
  redirect back to the map with a "processing…" indicator that clears via Turbo Stream
  once complete (or shows the error if `status: failed`).

---

## Open Questions to Resolve Before/During Build

1. **IPv6 support** — do scouts' traceroutes need to handle IPv6 hops? Affects
   `IpClassifier` (ULA/link-local ranges) and whether the MMDB lookup needs an IPv6-capable
   database variant. Recommend deferring — scope to IPv4 first unless you expect it.
2. **Timeout-gap link rendering** — dashed edge vs. just a normal edge; cosmetic decision,
   low risk either way.
3. **Layout re-run cadence** — pick (a) or (b) from §5 based on how it feels in a live test
   with a handful of simulated concurrent submissions.
4. **Rate of `mmdb` refresh** — weekly rake task is a reasonable default; not critical to
   get exactly right before the workshop.