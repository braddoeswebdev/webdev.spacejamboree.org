namespace :geoip do
  desc "Download the IPLocate.io free IP-to-ASN MMDB database"
  task update: :environment do
    url = ENV.fetch("GEOIP_DOWNLOAD_URL", "https://ip-locate.io/download/free/ip_to_asn.mmdb")
    dest = Rails.root.join("db/geoip/ip_to_asn.mmdb")
    dest.dirname.mkpath

    puts "Downloading MMDB from #{url}..."
    system "curl", "-sL", "-o", dest.to_s, url, exception: true
    size = File.size(dest)
    puts "Downloaded #{size} bytes to #{dest}"

    raise "Downloaded file is empty" if size.zero?
  rescue => e
    puts "ERROR: #{e.message}"
    puts "You can set GEOIP_DOWNLOAD_URL env var to override the download URL."
    raise
  end
end
