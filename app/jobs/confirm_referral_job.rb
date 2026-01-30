# frozen_string_literal: true

# Job to confirm a referral after the 24-hour waiting period.
#
# This job is enqueued when a referral is created, with a 24-hour delay.
# It verifies that the referee is still subscribed before confirming.
#
class ConfirmReferralJob < ApplicationJob
  queue_as :default

  def perform(referral_id)
    referral = Referral.find_by(id: referral_id)
    return unless referral # Record may have been deleted

    # Skip if not pending (already processed or cancelled)
    return unless referral.pending?

    referee_subscription = referral.referee_subscription

    if referee_subscription.active?
      confirm_referral(referral)
    else
      cancel_referral(referral)
    end
  rescue StandardError => e
    log_job_error(e, referral_id: referral_id)
    raise
  end

  private

  def confirm_referral(referral)
    ActsAsTenant.with_tenant(referral.site.tenant) do
      referral.confirm!
      check_and_award_rewards(referral)
      send_confirmation_email(referral)
    end
  end

  def cancel_referral(referral)
    referral.cancel!
    Rails.logger.info("Referral #{referral.id} cancelled: referee unsubscribed before confirmation")
  end

  def check_and_award_rewards(referral)
    ReferralRewardService.new(referral.referrer_subscription).check_and_award!
  end

  def send_confirmation_email(referral)
    ReferralMailer.referral_confirmed(referral).deliver_later
  end
end
