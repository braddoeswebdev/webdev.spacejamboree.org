class IpClassifier
  CGNAT = IPAddr.new("100.64.0.0/10")

  def self.private?(ip)
    addr = IPAddr.new(ip)
    addr.loopback? ||
      addr.link_local? ||
      addr.private? ||
      CGNAT.include?(addr)
  rescue IPAddr::InvalidAddressError
    true
  end

  def self.classify(ip)
    private?(ip) ? :private : :public
  end
end
