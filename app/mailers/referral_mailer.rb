# frozen_string_literal: true

class ReferralMailer < ApplicationMailer
  # Notify referrer when their referral has been confirmed
  def referral_confirmed(referral)
    @referral = referral
    @subscription = referral.referrer_subscription
    @user = @subscription.user
    @site = @subscription.site
    @tenant = @site.tenant

    @referee_name = referral.referee_user.display_name || "A new subscriber"
    @total_referrals = @subscription.confirmed_referrals_count
    @referral_link = @subscription.referral_link

    mail(
      to: @user.email,
      subject: I18n.t("referral_mailer.referral_confirmed.subject", site: @site.name),
      from: mailer_from_address
    )
  end

  # Notify referrer when they've unlocked a milestone reward
  def reward_unlocked(subscription, tier)
    @subscription = subscription
    @tier = tier
    @user = subscription.user
    @site = subscription.site
    @tenant = @site.tenant

    @reward_name = tier.name
    @total_referrals = subscription.confirmed_referrals_count
    @referral_link = subscription.referral_link

    mail(
      to: @user.email,
      subject: I18n.t("referral_mailer.reward_unlocked.subject", reward: @reward_name, site: @site.name),
      from: mailer_from_address
    )
  end

  private

  def mailer_from_address
    site_email = @site.setting("email.from_address")
    return site_email if site_email.present?

    tenant_email = @tenant.setting("email.from_address")
    return tenant_email if tenant_email.present?

    "referrals@#{@site.primary_hostname || 'curated.cx'}"
  end
end
