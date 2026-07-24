class Organization < ApplicationRecord
  has_many :network_nodes, dependent: :nullify

  validates :asn, uniqueness: true, allow_nil: true
  validates :name, presence: true
  validates :color, presence: true
end
