class Workshop < ApplicationRecord
  belongs_to :instructor, class_name: "User"
  has_many :participations
  has_many :completions, through: :participations
  has_many :participants, through: :participations, source: :user
  has_many :internet_maps, dependent: :destroy

  after_create :create_default_internet_map
  after_save :regenerate_completions, if: :participations_changed?

  def create_default_internet_map
    internet_maps.create!
  end

  def participations_changed?
    saved_changes.key?(:id) || participations.loaded? && participations.any?(&:new_record?)
  end

  def regenerate_completions
    participations.each do |participation|
      Requirement.all.each do |req|
        Completion.find_or_create_by(participation: participation, requirement: req)
      end
    end
  end
end
