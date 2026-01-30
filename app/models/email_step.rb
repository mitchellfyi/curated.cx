# frozen_string_literal: true

class EmailStep < ApplicationRecord
  # Associations
  belongs_to :email_sequence
  has_many :sequence_emails, dependent: :destroy

  # Validations
  validates :subject, presence: true
  validates :body_html, presence: true
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :delay_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :ordered, -> { order(position: :asc) }

  # Returns delay as ActiveSupport::Duration
  def delay_duration
    delay_seconds.seconds
  end
end
