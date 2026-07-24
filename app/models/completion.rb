class Completion < ApplicationRecord
  belongs_to :requirement
  belongs_to :participation
  has_one :workshop, through: :participation
  delegate :user, to: :participation
  has_rich_text :artifacts

  before_create :populate_artifacts

  private

  def populate_artifacts
    self.artifacts = requirement.template.body
  end
end
