class Traceroute < ApplicationRecord
  belongs_to :user
  belongs_to :internet_map
  has_many :network_nodes, dependent: :destroy
  has_many :network_links, dependent: :destroy

  enum :status, { pending: 0, processing: 1, complete: 2, failed: 3 }

  validates :target_domain, presence: true
  validates :raw_output, presence: true
end
