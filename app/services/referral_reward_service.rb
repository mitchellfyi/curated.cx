# frozen_string_literal: true

# Service for checking and awarding referral rewards based on milestone tiers.
#
# Usage:
#   service = ReferralRewardService.new(subscription)
#   service.check_and_award!  # Checks milestones and sends emails for new rewards
#   service.earned_rewards    # Returns list of earned reward tiers
#   service.pending_rewards   # Returns next tier info for progress display
#
class ReferralRewardService
  attr_reader :subscription

  def initialize(subscription)
    @subscription = subscription
  end

  # Check if any new milestones have been reached and award them
  def check_and_award!
    return [] if subscription.blank?

    confirmed_count = subscription.confirmed_referrals_count
    newly_earned = []

    eligible_tiers.each do |tier|
      next if tier.milestone > confirmed_count
      next if already_rewarded_for_milestone?(tier.milestone)

      mark_referrals_rewarded_up_to(tier.milestone)
      send_reward_email(tier)
      enroll_in_milestone_sequences(tier.milestone)
      newly_earned << tier
    end

    newly_earned
  end

  # Returns all reward tiers earned by this subscription
  def earned_rewards
    return [] if subscription.blank?

    confirmed_count = subscription.confirmed_referrals_count
    eligible_tiers.select { |tier| tier.milestone <= confirmed_count }
  end

  # Returns the next reward tier to work towards
  def next_reward
    return nil if subscription.blank?

    confirmed_count = subscription.confirmed_referrals_count
    eligible_tiers.find { |tier| tier.milestone > confirmed_count }
  end

  # Returns progress info: current count, next milestone, referrals needed
  def progress
    confirmed_count = subscription&.confirmed_referrals_count || 0
    next_tier = next_reward

    {
      confirmed_count: confirmed_count,
      next_milestone: next_tier&.milestone,
      referrals_needed: next_tier ? (next_tier.milestone - confirmed_count) : nil,
      next_reward_name: next_tier&.name
    }
  end

  private

  def eligible_tiers
    @eligible_tiers ||= ReferralRewardTier
      .where(site: subscription.site)
      .active
      .ordered_by_milestone
      .to_a
  end

  def already_rewarded_for_milestone?(milestone)
    # Check if we have enough rewarded referrals to have already reached this milestone
    rewarded_count = subscription.referrals_as_referrer.rewarded.count
    rewarded_count >= milestone
  end

  def mark_referrals_rewarded_up_to(milestone)
    # Mark confirmed referrals as rewarded up to the milestone count
    referrals_to_mark = subscription.referrals_as_referrer
      .confirmed
      .order(confirmed_at: :asc)
      .limit(milestone - subscription.referrals_as_referrer.rewarded.count)

    referrals_to_mark.each(&:mark_rewarded!)
  end

  def send_reward_email(tier)
    ReferralMailer.reward_unlocked(subscription, tier).deliver_later
  end

  def enroll_in_milestone_sequences(milestone)
    SequenceEnrollmentService.new(subscription).enroll_on_referral_milestone!(milestone)
  end
end
