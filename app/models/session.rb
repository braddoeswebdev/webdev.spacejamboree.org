class Session < ApplicationRecord
  belongs_to :user
  belongs_to :impersonator, class_name: "Session", optional: true
  has_many :impersonated_sessions, class_name: "Session", foreign_key: :impersonator_id, dependent: :destroy

  def impersonating?
    impersonator_id.present?
  end
end
