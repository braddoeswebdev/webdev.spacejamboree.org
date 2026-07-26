Doorkeeper::OpenidConnect.configure do
  issuer "https://webdev.spacejamboree.org"

  signing_key ENV["OIDC_RSA_PRIVATE_KEY"] || Rails.root.join("config/keys/oidc-private.pem").read

  subject_types_supported [ :public ]

  resource_owner_from_access_token do |access_token|
    User.find_by(id: access_token.resource_owner_id)
  end

  auth_time_from_resource_owner do |resource_owner|
    resource_owner&.updated_at
  end

  reauthenticate_resource_owner do |resource_owner, return_to|
    store_location_for resource_owner, return_to
    terminate_session
    redirect_to new_session_path
  end

  select_account_for_resource_owner do |_resource_owner_or_nil, return_to|
    store_location_for resource_owner_or_nil, return_to
    redirect_to account_select_url
  end

  subject do |resource_owner, _application|
    resource_owner.id
  end

  claims do
    normal_claim :name, scope: :profile, response: [ :id_token, :user_info ] do |resource_owner|
      resource_owner.name
    end

    normal_claim :email, scope: :email, response: [ :id_token, :user_info ] do |resource_owner|
      resource_owner.email_address
    end
  end
end
