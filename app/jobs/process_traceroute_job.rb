class ProcessTracerouteJob < ApplicationJob
  queue_as :default

  def perform(traceroute)
    traceroute.update!(status: :processing)

    hops = TracerouteParser.parse(traceroute.raw_output, target_domain: traceroute.target_domain)

    origin = create_origin_node(traceroute)
    previous_node = origin
    consolidated_private = nil

    links = []

    hops.each do |hop|
      if hop.timed_out
        consolidated_private = nil
        links << { timed_out: true, hop_number: hop.position }
        next
      end

      is_private = IpClassifier.private?(hop.ip)

      if is_private && consolidated_private
        next
      end

      consolidated_private = nil

      dedupe_key = NetworkNodeDedupeKey.build(
        internet_map_id: traceroute.internet_map_id,
        user_id: traceroute.user_id,
        ip_address: hop.ip,
        is_private: is_private
      )

      node = find_or_create_node(traceroute, hop, dedupe_key, is_private)
      enqueue_asn_enrichment(node) unless is_private

      consolidated_private = node if is_private

      rtt_json = hop.rtt_samples.presence && hop.rtt_samples.to_json

      links << {
        start_node: previous_node,
        end_node: node,
        hop_number: hop.position,
        rtt_samples: rtt_json,
        timed_out: false,
        spans_gap: false
      }

      previous_node = node
    end

    fill_timeout_gaps(links, hops)
    create_links!(traceroute, links)

    traceroute.update!(status: :complete)
    broadcast_update(traceroute)
  rescue TracerouteParser::ParseError => e
    traceroute.update!(status: :failed, error_message: e.message)
  rescue => e
    traceroute.update!(status: :failed, error_message: e.message)
  end

  private

  def create_origin_node(traceroute)
    dedupe_key = "origin:#{traceroute.internet_map_id}:#{traceroute.user_id}"
    NetworkNode.find_or_create_by!(dedupe_key: dedupe_key) do |n|
      n.internet_map = traceroute.internet_map
      n.traceroute = traceroute
      n.user = traceroute.user
      n.ip_address = "0.0.0.0"
      n.hostname = traceroute.user.name
      n.is_private = true
    end
  end

  def find_or_create_node(traceroute, hop, dedupe_key, is_private)
    NetworkNode.find_or_create_by!(dedupe_key: dedupe_key) do |n|
      n.internet_map = traceroute.internet_map
      n.traceroute = traceroute
      n.user = traceroute.user
      n.ip_address = hop.ip
      n.hostname = is_private ? "Local Network" : (hop.hostname || hop.ip)
      n.is_private = is_private
    end
  end

  def enqueue_asn_enrichment(node)
    return if node.organization_id.present?

    lookup = AsnLookup.lookup(node.ip_address)
    return unless lookup

    org = Organization.find_or_create_by!(asn: lookup[:asn]) do |o|
      o.name = lookup[:org_name]
      o.org_domain = lookup[:org_domain]
      o.seeded = false
      o.color = ColorAssigner.next_color_for(existing: Organization.pluck(:color))
    end

    node.update!(organization: org)
  end

  def fill_timeout_gaps(links, hops)
    return if links.size < 2

    links.each_cons(2).with_index do |(prev_link, next_link), i|
      prev_hop = hops.find { |h| h.position == prev_link[:hop_number] }
      next_hop = hops.find { |h| h.position == next_link[:hop_number] }
      next unless prev_hop && next_hop

      gap_positions = hops.select { |h| h.position > prev_hop.position && h.position < next_hop.position }
      if gap_positions.any? { |h| h.timed_out }
        next_link[:spans_gap] = true
      end
    end
  end

  def create_links!(traceroute, links)
    existing_pairs = Set.new(
      NetworkLink.joins(:traceroute)
        .where(traceroutes: { internet_map_id: traceroute.internet_map_id })
        .pluck(:start_node_id, :end_node_id)
    )

    links.each do |link_data|
      next unless link_data[:start_node] && link_data[:end_node]
      next if existing_pairs.include?([ link_data[:start_node].id, link_data[:end_node].id ])

      NetworkLink.create!(
        traceroute: traceroute,
        start_node: link_data[:start_node],
        end_node: link_data[:end_node],
        hop_number: link_data[:hop_number],
        rtt_samples: link_data[:rtt_samples],
        timed_out: link_data[:timed_out],
        spans_gap: link_data[:spans_gap]
      )
    end
  end

  def broadcast_update(traceroute)
    internet_map = traceroute.internet_map
    nodes = traceroute.network_nodes.includes(:organization).to_a
    links = traceroute.network_links.to_a

    return if nodes.empty? && links.empty?

    last_link = links.max_by(&:hop_number)
    final_node_id = last_link&.end_node_id
    domain = traceroute.target_domain

    elements = {
      nodes: nodes.map { |n| serialize_node(n, final_node_id: final_node_id, domain: domain) },
      edges: links.map { |l| serialize_link(l) }
    }

    Turbo::StreamsChannel.broadcast_append_to(
      "internet_map_#{internet_map.id}",
      target: "map-stream",
      partial: "internet_maps/map_stream",
      locals: { elements: elements }
    )
  end

  def serialize_node(node, final_node_id: nil, domain: nil)
    data = {
      id: "node_#{node.id}",
      label: node.hostname || node.ip_address,
      ip: node.ip_address,
      org_name: node.organization&.name,
      org_color: node.organization&.color || (node.is_private ? "#a9a9a9" : "#808080"),
      is_private: node.is_private,
      x: node.x,
      y: node.y,
      user_name: node.user.name,
      domain: (node.id == final_node_id) ? domain : nil
    }
    if data[:domain]
      data[:label] = "#{data[:domain]}\n#{data[:label]}"
    end
    { data: data }
  end

  def serialize_link(link)
    {
      data: {
        id: "link_#{link.id}",
        source: "node_#{link.start_node_id}",
        target: "node_#{link.end_node_id}",
        label: link.rtt_samples.presence,
        hop_number: link.hop_number,
        spans_gap: link.spans_gap,
        timed_out: link.timed_out
      }
    }
  end
end
