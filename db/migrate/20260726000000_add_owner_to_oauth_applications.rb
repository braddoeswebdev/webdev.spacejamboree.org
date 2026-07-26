class AddOwnerToOauthApplications < ActiveRecord::Migration[8.1]
  def change
    add_reference :oauth_applications, :owner, polymorphic: true, index: true
  end
end
