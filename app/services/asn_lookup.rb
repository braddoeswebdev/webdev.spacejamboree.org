class AsnLookup
  MMDB_PATH = Rails.root.join("db/geoip/ip_to_asn.mmdb")

  def self.lookup(ip)
    return nil unless File.exist?(MMDB_PATH)

    @db ||= MaxMind::DB.new(MMDB_PATH.to_s, mode: MaxMind::DB::MODE_MEMORY)
    result = @db.get(ip)

    return nil unless result&.dig("asn")

    {
      asn: result["asn"].to_i,
      org_name: result["org"],
      org_domain: result["domain"]
    }
  rescue => e
    Rails.logger.warn "ASN lookup failed for #{ip}: #{e.message}"
    nil
  end
end
