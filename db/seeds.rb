# Seed known organizations with fixed colors for the Internet Map feature.
# These are the heavy hitters a scout cohort is likely to encounter.
seeded_orgs = [
  { name: "Cloudflare", asn: 13335, color: "#f38020" },
  { name: "Google", asn: 15169, color: "#4285f4" },
  { name: "Amazon Web Services", asn: 16509, color: "#ff9900" },
  { name: "Microsoft", asn: 8075, color: "#00a4ef" },
  { name: "Meta", asn: 32934, color: "#0866ff" },
  { name: "Comcast", asn: 7922, color: "#012d5e" },
  { name: "AT&T", asn: 7018, color: "#009fdb" },
  { name: "Verizon", asn: 701, color: "#e00000" },
  { name: "Spectrum / Charter", asn: 20115, color: "#00205b" },
  { name: "T-Mobile", asn: 21928, color: "#e20074" }
]

seeded_orgs.each do |attrs|
  Organization.find_or_create_by!(asn: attrs[:asn]) do |o|
    o.name = attrs[:name]
    o.color = attrs[:color]
    o.seeded = true
  end
end

puts "Seeded #{seeded_orgs.size} organizations."
