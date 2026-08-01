Hop = Data.define(:position, :ip, :hostname, :rtt_samples, :timed_out)

class TracerouteParser
  ParseError = Class.new(StandardError)

  def self.parse(raw_output, target_domain:)
    lines = raw_output.strip.lines.map(&:chomp).reject(&:empty?)
    raise ParseError, "No output to parse" if lines.empty?

    format = detect_format(lines)
    send(:"parse_#{format}", lines)
  rescue ParseError
    raise
  rescue => e
    raise ParseError, "Unexpected parse error: #{e.message}"
  end

  def self.detect_format(lines)
    unix_score = lines.count { |l| l.match?(/^\s*\d+\s+\S+\s+\d+\.\d+\s*ms/i) }
    windows_score = lines.count { |l| l.match?(/^\s*\d+\s+<?\d+\s*ms(?!\S)/) }

    if windows_score > unix_score
      :windows
    else
      :unix
    end
  end

  def self.parse_unix(lines)
    hops = []
    last_position = nil

    lines.each do |line|
      raw = line
      line = line.strip
      next if line.empty? || line.match?(/^traceroute to /i)

      if line.match?(/\A\d+\s+\*\s+\*\s+\*/)
        pos = line.match(/\A(\d+)/)&.[](1)&.to_i
        hops << Hop.new(position: pos, ip: nil, hostname: nil, rtt_samples: [], timed_out: true)
        last_position = pos
        next
      end

      continuation = !line.match?(/\A\d+\s/)
      if continuation
        unless last_position
          raise ParseError, "Could not parse Unix line: #{line}"
        end

        pos = last_position
        m = line.match(/\A(\S+)\s+\((\S+)\)\s+(.+)/)
        raise ParseError, "Could not parse Unix line: #{raw}" unless m

        hostname = m[1]
        ip = m[2]
        rtt_raw = m[3]
      else
        m = line.match(/\A(\d+)\s+(\S+)\s+\((\S+)\)\s+(.+)/)
        if m
          pos = m[1].to_i
          hostname = m[2]
          ip = m[3]
          rtt_raw = m[4]
        else
          m = line.match(/\A(\d+)\s+(\S+)\s+(.+)/)
          raise ParseError, "Could not parse Unix line: #{raw}" unless m

          pos = m[1].to_i
          hostname = nil
          ip = m[2]
          rtt_raw = m[3]
        end
      end

      rtts = rtt_raw.scan(/([\d.]+)\s*ms/).flatten.map(&:to_f)
      hops << Hop.new(position: pos, ip: ip, hostname: hostname, rtt_samples: rtts, timed_out: false)
      last_position = pos
    end

    hops
  end

  def self.parse_windows(lines)
    hops = []

    lines.each do |line|
      line = line.strip
      next if line.empty? || line.match?(/^(Tracing|over| tracert)/i)

      if line.match?(/Request timed out/i)
        pos_match = line.match(/\A\s*(\d+)/)
        pos = pos_match ? pos_match[1].to_i : (hops.size + 1)
        hops << Hop.new(position: pos, ip: nil, hostname: nil, rtt_samples: [], timed_out: true)
        next
      end

      m = line.match(/\A\s*(\d+)\s+(<?\d+)\s*ms\s+(<?\d+)\s*ms\s+(<?\d+)\s*ms\s+(\S+)/)
      m ||= line.match(/\A\s*(\d+)\s+(<?\d+)\s*ms\s+(<?\d+)\s*ms\s+(<?\d+)\s*ms\s*/)
      raise ParseError, "Could not parse Windows line: #{line}" unless m

      pos = m[1].to_i
      rtts = [ m[2], m[3], m[4] ].map { |v| v.start_with?("<") ? 0.0 : v.to_f }

      ip_or_host = m[5]
      hops << if ip_or_host && ip_or_host.match?(/\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/)
        Hop.new(position: pos, ip: ip_or_host, hostname: nil, rtt_samples: rtts, timed_out: false)
      elsif ip_or_host
        Hop.new(position: pos, ip: ip_or_host, hostname: ip_or_host, rtt_samples: rtts, timed_out: false)
      else
        Hop.new(position: pos, ip: nil, hostname: nil, rtt_samples: rtts, timed_out: true)
      end
    end

    hops
  end
end
