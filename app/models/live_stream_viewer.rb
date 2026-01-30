# frozen_string_literal: true

class LiveStreamViewer < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :live_stream
  belongs_to :user, optional: true

  # Validations
  validates :joined_at, presence: true
  validate :must_have_user_or_session

  # Scopes
  scope :active, -> { where(left_at: nil) }
  scope :completed, -> { where.not(left_at: nil) }

  # Instance methods
  def active?
    left_at.nil?
  end

  def leave!
    return if left_at.present?

    update!(
      left_at: Time.current,
      duration_seconds: calculate_duration
    )
  end

  def calculate_duration
    return nil unless joined_at.present?

    end_time = left_at || Time.current
    (end_time - joined_at).to_i
  end

  private

  def must_have_user_or_session
    return if user_id.present? || session_id.present?

    errors.add(:base, "must have either a user or a session_id")
  end
end
