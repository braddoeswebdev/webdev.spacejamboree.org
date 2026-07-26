class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :participations, dependent: :destroy
  has_many :oauth_applications, class_name: "Doorkeeper::Application", as: :owner, dependent: :destroy
  has_many :oauth_access_grants, class_name: "Doorkeeper::AccessGrant", foreign_key: :resource_owner_id, dependent: :destroy
  has_many :oauth_access_tokens, class_name: "Doorkeeper::AccessToken", foreign_key: :resource_owner_id, dependent: :destroy
  has_many :completions, through: :participations
  has_many :workshops, through: :participations
  has_many :instructed_workshops, class_name: "Workshop", foreign_key: "instructor_id"
  has_many :traceroutes, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  after_save :regenerate_completions, if: -> { previous_changes.key?("updated_at") && workshops.any? }

  def regenerate_completions
    workshops.each do |workshop|
      Requirement.all.each do |req|
        Completion.find_or_create_by(participation: participations.find_by(workshop: workshop), requirement: req)
      end
    end
  end
end
