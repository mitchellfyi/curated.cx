# frozen_string_literal: true

class ReferralsController < ApplicationController
  before_action :authenticate_user!
  skip_after_action :verify_policy_scoped

  def show
    @subscription = current_user.digest_subscriptions.find_by(site: Current.site)
    authorize(@subscription || DigestSubscription, policy_class: ReferralPolicy)

    return redirect_to_subscribe_first unless @subscription

    @reward_service = ReferralRewardService.new(@subscription)
    @progress = @reward_service.progress
    @earned_rewards = @reward_service.earned_rewards
    @referrals = @subscription.referrals_as_referrer.recent.limit(20)
  end

  private

  def redirect_to_subscribe_first
    redirect_to digest_subscription_path, alert: t("referrals.subscribe_first")
  end
end
