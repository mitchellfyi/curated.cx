# frozen_string_literal: true

class ProcessSequenceEnrollmentsJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 100

  def perform
    SequenceEmail
      .pending
      .due
      .includes(sequence_enrollment: { email_sequence: :site, digest_subscription: :user })
      .find_each(batch_size: BATCH_SIZE) do |sequence_email|
        process_email(sequence_email)
      end
  end

  private

  def process_email(sequence_email)
    enrollment = sequence_email.sequence_enrollment
    subscription = enrollment.digest_subscription
    site = enrollment.email_sequence.site

    # Stop enrollment if subscription is no longer active
    unless subscription.active?
      enrollment.stop!
      return
    end

    ActsAsTenant.with_tenant(site.tenant) do
      mailer = SequenceMailer.step_email(sequence_email)

      # deliver_later returns nil if the mailer action returns early
      if mailer&.message&.present?
        mailer.deliver_later
        sequence_email.mark_sent!
        enrollment.schedule_next_email!
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send sequence email #{sequence_email.id}: #{e.message}")
    sequence_email.mark_failed!
    # Continue to next email
  end
end
