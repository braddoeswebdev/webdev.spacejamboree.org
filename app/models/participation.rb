class Participation < ApplicationRecord
  belongs_to :workshop
  belongs_to :user
  has_many :completions, dependent: :destroy
end
