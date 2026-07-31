require "test_helper"

class ImpersonationTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email_address: "admin@example.com", name: "Admin", password: "password123", admin: true)
    @target = User.create!(email_address: "target@example.com", name: "Target", password: "password123")
  end

  teardown do
    User.destroy_all
  end

  test "admin can impersonate a user and stop" do
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    assert_response :redirect

    assert_difference -> { Session.count }, 1 do
      post impersonate_user_url(@target)
    end
    assert_response :redirect

    impersonated_session = Session.find_by(user: @target)
    admin_session = Session.find_by(user: @admin)
    assert impersonated_session.present?
    assert_equal admin_session.id, impersonated_session.impersonator_id

    get root_url
    assert_response :success
    assert_match /You are impersonating Target/, response.body
    assert_match /action="\/impersonation"/, response.body

    assert_difference -> { Session.count }, -1 do
      delete stop_impersonation_url
    end
    assert_response :redirect

    get root_url
    assert_response :success
    assert_no_match /You are impersonating/, response.body
  end

  test "non-admin cannot impersonate" do
    post session_url, params: { email_address: @target.email_address, password: "password123" }
    assert_response :redirect

    post impersonate_user_url(@admin)
    assert_response :redirect
    assert_equal root_url, response.location

    assert_no_difference -> { Session.count } do
      get root_url
    end
  end

  test "admin cannot impersonate themselves" do
    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    assert_response :redirect

    post impersonate_user_url(@admin)
    assert_response :redirect
    assert_equal users_url, response.location

    get root_url
    assert_response :success
    assert_no_match /You are impersonating/, response.body
  end

  test "impersonated session cannot impersonate another user" do
    other = User.create!(email_address: "other@example.com", name: "Other", password: "password123")

    post session_url, params: { email_address: @admin.email_address, password: "password123" }
    post impersonate_user_url(@target)
    assert_response :redirect

    assert_no_difference -> { Session.count } do
      post impersonate_user_url(other)
    end
    assert_equal root_url, response.location
  end
end
