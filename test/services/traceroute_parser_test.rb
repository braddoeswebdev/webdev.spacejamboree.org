require "test_helper"

class TracerouteParserTest < ActiveSupport::TestCase
  test "parses macOS traceroute with multi-address continuation lines" do
    input = <<~TR
      1  rbe971 (192.168.1.1)  6.964 ms  2.753 ms  2.985 ms
       2  10.0.0.1 (10.0.0.1)  5.369 ms  5.050 ms  3.958 ms
       8  50.145.121.166 (50.145.121.166)  12.930 ms
          50.145.121.170 (50.145.121.170)  16.891 ms  18.835 ms
      10  108.170.235.209 (108.170.235.209)  20.777 ms
          142.251.228.229 (142.251.228.229)  14.533 ms
          108.170.235.209 (108.170.235.209)  14.358 ms
      11  pnsfoa-ae-in-f14.1e100.net (142.251.214.46)  17.789 ms  14.629 ms  15.508 ms
    TR

    hops = TracerouteParser.parse(input, target_domain: "example.com")

    assert_equal 8, hops.size
    assert_equal [ 1, 2, 8, 8, 10, 10, 10, 11 ], hops.map(&:position)
    assert_equal "50.145.121.166", hops[2].ip
    assert_equal [ 12.93 ], hops[2].rtt_samples
    assert_equal 8, hops[3].position
    assert_equal "50.145.121.170", hops[3].ip
    assert_equal [ 16.891, 18.835 ], hops[3].rtt_samples
    assert_equal "142.251.228.229", hops[5].ip
  end

  test "parses unix traceroute with timeouts" do
    input = <<~TR
      traceroute to example.com (93.184.216.34), 30 hops max
       1  192.168.1.1 (192.168.1.1)  1.123 ms  1.234 ms  1.345 ms
       2  * * *
       3  example.com (93.184.216.34)  10.111 ms  10.222 ms  10.333 ms
    TR

    hops = TracerouteParser.parse(input, target_domain: "example.com")

    assert_equal 3, hops.size
    assert hops[1].timed_out
    assert_equal 2, hops[1].position
    assert_equal "93.184.216.34", hops[2].ip
  end

  test "parses windows tracert output" do
    input = <<~TR
      Tracing route to example.com over a maximum of 30 hops
        1    <1 ms    <1 ms     1 ms  192.168.1.1
        2     *        *        *     Request timed out.
        3     4 ms     5 ms     6 ms  example.com [93.184.216.34]
    TR

    hops = TracerouteParser.parse(input, target_domain: "example.com")

    assert_equal 3, hops.size
    assert_equal "192.168.1.1", hops[0].ip
    assert hops[1].timed_out
    assert_equal "example.com", hops[2].hostname
  end
end
