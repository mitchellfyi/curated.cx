# frozen_string_literal: true

# Service for enrolling subscribers in email sequences.
#
# Usage:
#   service = SequenceEnrollmentService.new(digest_subscription)
#   service.enroll_on_subscription!  # Enrolls in subscriber_joined sequences
#   service.enroll_on_referral_milestone!(5)  # Enrolls in referral_milestone sequences for milestone 5
#
class SequenceEnrollmentService
  attr_reader :digest_subscription

  def initialize(digest_subscription)
    @digest_subscription = digest_subscription
  end

  # Enroll the subscriber in all matching subscriber_joined sequences
  def enroll_on_subscription!
    return [] if digest_subscription.blank?

    sequences = enabled_sequences_for_trigger(:subscriber_joined)
    sequences.filter_map { |sequence| create_enrollment(sequence) }
  end

  # Enroll the subscriber in all matching referral_milestone sequences for a specific milestone
  def enroll_on_referral_milestone!(milestone)
    return [] if digest_subscription.blank?

    sequences = enabled_sequences_for_trigger(:referral_milestone)
      .select { |seq| seq.trigger_config[:milestone].to_i == milestone.to_i }

    sequences.filter_map { |sequence| create_enrollment(sequence) }
  end

  private

  def enabled_sequences_for_trigger(trigger_type)
    EmailSequence
      .without_site_scope
      .where(site: digest_subscription.site)
      .enabled
      .for_trigger(trigger_type)
      .to_a
  end

  def create_enrollment(sequence)
    # Use find_or_initialize to prevent duplicate enrollments
    enrollment = SequenceEnrollment.find_or_initialize_by(
      email_sequence: sequence,
      digest_subscription: digest_subscription
    )

    # Skip if already enrolled
    return nil if enrollment.persisted?

    enrollment.enrolled_at = Time.current
    enrollment.status = :active
    enrollment.current_step_position = 0

    return nil unless enrollment.save

    # Schedule the first email
    enrollment.schedule_next_email!
    enrollment
  end
end
