# frozen_string_literal: true

# == Schema Information
#
# Table name: sequence_emails
#
#  id                     :bigint           not null, primary key
#  scheduled_for          :datetime         not null
#  sent_at                :datetime
#  status                 :integer          default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  email_step_id          :bigint           not null
#  sequence_enrollment_id :bigint           not null
#
# Indexes
#
#  index_sequence_emails_on_email_step_id             (email_step_id)
#  index_sequence_emails_on_sequence_enrollment_id    (sequence_enrollment_id)
#  index_sequence_emails_on_status_and_scheduled_for  (status,scheduled_for)
#
# Foreign Keys
#
#  fk_rails_...  (email_step_id => email_steps.id)
#  fk_rails_...  (sequence_enrollment_id => sequence_enrollments.id)
#
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
