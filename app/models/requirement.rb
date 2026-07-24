class Requirement < ApplicationRecord
  belongs_to :badge
  has_many :completions, dependent: :destroy
  has_rich_text :description
  has_rich_text :template
end
