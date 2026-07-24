class InternetMap < ApplicationRecord
  belongs_to :workshop
  has_many :network_nodes, dependent: :destroy
  has_many :traceroutes, dependent: :destroy
  has_many :network_links, through: :traceroutes
end
