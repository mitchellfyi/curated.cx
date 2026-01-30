# frozen_string_literal: true

class SequenceEmail < ApplicationRecord
  # Associations
  belongs_to :sequence_enrollment
  belongs_to :email_step

  # Enums
  enum :status, { pending: 0, sent: 1, failed: 2 }, default: :pending

  # Validations
  validates :scheduled_for, presence: true

  # Scopes
  scope :due, -> { where("scheduled_for <= ?", Time.current) }

  # Mark email as sent
  def mark_sent!
    update!(status: :sent, sent_at: Time.current)
  end

  # Mark email as failed
  def mark_failed!
    update!(status: :failed)
  end
end
