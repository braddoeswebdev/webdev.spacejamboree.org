class Badge < ApplicationRecord
  has_many :requirements, dependent: :destroy
  has_rich_text :description
  has_one_attached :image
end
