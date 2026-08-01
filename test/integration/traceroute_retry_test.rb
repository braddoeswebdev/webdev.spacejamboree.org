require "test_helper"

class TracerouteRetryTest < ActionDispatch::IntegrationTest
  setup do
    @instructor = User.create!(email_address: "instructor@example.com", name: "Instructor", password: "password123")
    @scout = User.create!(email_address: "scout@example.com", name: "Scout", password: "password123")
    @workshop = Workshop.create!(name: "Networking 101", instructor: @instructor)
    @internet_map = @workshop.internet_maps.first
    @scout.participations.create!(workshop: @workshop)

    @traceroute = @internet_map.traceroutes.create!(
      user: @scout,
      target_domain: "google.com",
      raw_output: "1  rbe971 (192.168.1.1)  6.964 ms\n",
      status: :failed,
      error_message: "Could not parse Unix line: 50.145.121.170 (50.145.121.170)  16.891 ms  18.835 ms"
    )
  end

  teardown do
    Participation.destroy_all
    Workshop.destroy_all
    User.destroy_all
  end

  test "failed traceroute shows a retry button in the submissions list" do
    post session_url, params: { email_address: @scout.email_address, password: "password123" }
    assert_response :redirect

    get internet_map_url(@internet_map)
    assert_response :success
    assert_match /Re-run this traceroute/, response.body
    assert_match /internet_maps\/\d+\/traceroutes\/#{@traceroute.id}\/retry/, response.body
  end

  test "retrying a failed traceroute resets status and re-enqueues processing" do
    post session_url, params: { email_address: @scout.email_address, password: "password123" }
    assert_response :redirect

    assert_enqueued_with job: ProcessTracerouteJob, args: [ @traceroute ] do
      post retry_internet_map_traceroute_url(@internet_map, @traceroute)
    end
    assert_response :redirect
    assert_equal internet_map_url(@internet_map), response.location

    @traceroute.reload
    assert @traceroute.pending?
    assert_nil @traceroute.error_message
  end

  test "successful traceroute has no retry button" do
    complete = @internet_map.traceroutes.create!(
      user: @scout,
      target_domain: "example.com",
      raw_output: "1  rbe971 (192.168.1.1)  6.964 ms\n",
      status: :complete
    )

    post session_url, params: { email_address: @scout.email_address, password: "password123" }
    get internet_map_url(@internet_map)
    assert_response :success
    assert_match /example\.com/, response.body
    assert_no_match /Re-run example\.com/, response.body
    assert_no_match /traceroutes\/#{complete.id}\/retry/, response.body
  end
end
