class Completion < ApplicationRecord
  belongs_to :requirement
  belongs_to :participation
  has_one :workshop, through: :participation
  delegate :user, to: :participation
  has_rich_text :artifacts

  scope :blank, -> {
    left_joins(:rich_text_artifacts)
      .where("action_text_rich_texts.id IS NULL OR COALESCE(action_text_rich_texts.body, '') = ''")
  }
  scope :in_progress, -> {
    left_joins(:rich_text_artifacts)
      .where("action_text_rich_texts.id IS NOT NULL AND COALESCE(action_text_rich_texts.body, '') != ''")
      .where(complete: false)
  }
  scope :complete, -> { where(complete: true) }

  before_create :populate_artifacts

  def blank?
    artifacts.blank?
  end

  def in_progress?
    !blank? && !complete?
  end

  private

  def populate_artifacts
    self.artifacts = requirement.template.body
  end
end
