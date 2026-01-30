# frozen_string_literal: true

class SequenceEnrollment < ApplicationRecord
  # Associations
  belongs_to :email_sequence
  belongs_to :digest_subscription
  has_many :sequence_emails, dependent: :destroy

  # Enums
  enum :status, { active: 0, completed: 1, stopped: 2 }, default: :active

  # Validations
  validates :enrolled_at, presence: true
  validates :email_sequence_id, uniqueness: { scope: :digest_subscription_id }

  # Scopes
  scope :for_sequence, ->(sequence) { where(email_sequence: sequence) }

  # Stop the enrollment (e.g., subscriber unsubscribed)
  def stop!
    return false unless active?

    update!(status: :stopped)
    true
  end

  # Mark enrollment as completed
  def complete!
    return false unless active?

    update!(status: :completed, completed_at: Time.current)
    true
  end

  # Get the next step to send
  def next_step
    email_sequence.email_steps.ordered.offset(current_step_position).first
  end

  # Schedule the next email in the sequence
  def schedule_next_email!
    return if !active?

    step = next_step
    return complete! if step.nil?

    # Calculate when to send this step
    base_time = if current_step_position == 0
                  enrolled_at
    else
                  sequence_emails.order(scheduled_for: :desc).first&.scheduled_for || Time.current
    end

    scheduled_for = base_time + step.delay_duration

    sequence_emails.create!(
      email_step: step,
      scheduled_for: scheduled_for,
      status: :pending
    )

    increment!(:current_step_position)
  end
end
