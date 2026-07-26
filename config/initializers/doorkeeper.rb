Doorkeeper.configure do
  orm :active_record

  resource_owner_authenticator do
    Current.session ||= Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    Current.session&.user || redirect_to(new_session_path)
  end

  admin_authenticator do
    Current.session ||= Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]

    if Current.session&.user&.admin?
      Current.session.user
    else
      redirect_to new_session_path
    end
  end

  resource_owner_from_credentials do |_routes|
    User.authenticate_by(email_address: params[:email_address], password: params[:password])
  end

  default_scopes :openid, :profile, :email
  optional_scopes :admin

  grant_flows %w[authorization_code client_credentials]

  skip_authorization do |resource_owner, client|
    client.application.superapp? || resource_owner.admin?
  end

  allow_blank_redirect_uri true

  handle_auth_errors :raise

  access_token_expires_in 2.hours
  use_refresh_token

  enable_application_owner confirmation: false

  realm "Space Jamboree"
end
