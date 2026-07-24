class NetworkNode < ApplicationRecord
  belongs_to :internet_map
  belongs_to :traceroute
  belongs_to :user
  belongs_to :organization, optional: true

  validates :ip_address, presence: true
  validates :dedupe_key, presence: true, uniqueness: true
end
