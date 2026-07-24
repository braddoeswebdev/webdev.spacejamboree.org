class NetworkLink < ApplicationRecord
  belongs_to :traceroute
  belongs_to :start_node, class_name: "NetworkNode"
  belongs_to :end_node, class_name: "NetworkNode"

  serialize :rtt_samples, coder: JSON

  validates :hop_number, presence: true
end
