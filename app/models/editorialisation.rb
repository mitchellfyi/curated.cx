# frozen_string_literal: true

# Tracks AI editorialisation attempts for audit and reproducibility.
# Each ContentItem may have at most one editorialisation record (unique constraint).
#
# The model stores the full prompt text and raw response for debugging
# and prompt version tracking.
# == Schema Information
#
# Table name: editorialisations
#
#  id              :bigint           not null, primary key
#  ai_model        :string
#  duration_ms     :integer
#  error_message   :text
#  parsed_response :jsonb            not null
#  prompt_text     :text             not null
#  prompt_version  :string           not null
#  raw_response    :text
#  status          :integer          default("pending"), not null
#  tokens_used     :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  content_item_id :bigint           not null
#  site_id         :bigint           not null
#
# Indexes
#
#  index_editorialisations_on_content_item_id         (content_item_id) UNIQUE
#  index_editorialisations_on_site_id                 (site_id)
#  index_editorialisations_on_site_id_and_created_at  (site_id,created_at)
#  index_editorialisations_on_site_id_and_status      (site_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (content_item_id => content_items.id)
#  fk_rails_...  (site_id => sites.id)
#
class Editorialisation < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :content_item

  # Enums
  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3,
    skipped: 4
  }

  # Validations
  validates :content_item, presence: true
  validates :prompt_version, presence: true
  validates :prompt_text, presence: true
  validates :status, presence: true
  validates :tokens_used, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_ms, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(s) { where(status: s) }
  scope :pending, -> { where(status: :pending) }
  scope :processing, -> { where(status: :processing) }
  scope :completed, -> { where(status: :completed) }
  scope :failed, -> { where(status: :failed) }
  scope :skipped, -> { where(status: :skipped) }

  # Class methods
  def self.latest_for_content_item(content_item_id)
    where(content_item_id: content_item_id).order(created_at: :desc).first
  end

  # Instance methods

  # Mark as processing when AI call begins
  def mark_processing!
    update!(status: :processing)
  end

  # Mark as completed with successful response data
  def mark_completed!(parsed:, raw:, tokens:, duration:, model:)
    update!(
      status: :completed,
      parsed_response: parsed,
      raw_response: raw,
      tokens_used: tokens,
      duration_ms: duration,
      ai_model: model
    )
  end

  # Mark as failed with error message
  def mark_failed!(message)
    update!(
      status: :failed,
      error_message: message
    )
  end

  # Mark as skipped with reason
  def mark_skipped!(reason)
    update!(
      status: :skipped,
      error_message: reason
    )
  end

  # Get duration in seconds for display
  def duration_seconds
    return nil unless duration_ms
    duration_ms / 1000.0
  end

  # Convenience accessors for parsed response
  def ai_summary
    parsed_response["summary"]
  end

  def why_it_matters
    parsed_response["why_it_matters"]
  end

  def suggested_tags
    parsed_response["suggested_tags"] || []
  end

  # Default parsed_response to empty hash
  def parsed_response
    super || {}
  end
end
