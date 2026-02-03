# frozen_string_literal: true

# Service for attributing referrals when a new subscriber signs up with a referral code.
#
# Handles fraud prevention checks:
# - Validates referral code exists and belongs to active subscription
# - Prevents self-referral (same email domain)
# - Prevents IP abuse (same IP within 24h from same referrer)
#
# Usage:
#   service = ReferralAttributionService.new(
#     referee_subscription: subscription,
#     referral_code: "abc123",
#     ip_address: "192.168.1.1"
#   )
#   result = service.attribute!
#   if result[:success]
#     # Referral created
#   else
#     # result[:error] contains the reason
#   end
#
class ReferralAttributionService
  IP_COOLDOWN_HOURS = 24

  attr_reader :referee_subscription, :referral_code, :ip_address

  def initialize(referee_subscription:, referral_code:, ip_address: nil)
    @referee_subscription = referee_subscription
    @referral_code = referral_code
    @ip_address = ip_address
  end

  def attribute!
    return error("No referral code provided") if referral_code.blank?

    referrer = find_referrer_subscription
    return error("Invalid referral code") unless referrer
    return error("Referrer subscription is inactive") unless referrer.active?
    return error("Cannot refer yourself") if self_referral?(referrer)
    return error("Email domain matches referrer") if same_email_domain?(referrer)
    return error("Too many referrals from this IP") if ip_abuse?(referrer)
    return error("Already has a referral") if already_referred?

    create_referral(referrer)
  end

  private

  def find_referrer_subscription
    # Search within the same site only
    DigestSubscription.find_by(
      referral_code: referral_code,
      site: referee_subscription.site
    )
  end

  def self_referral?(referrer)
    referrer.user_id == referee_subscription.user_id
  end

  def same_email_domain?(referrer)
    referrer_domain = email_domain(referrer.user.email)
    referee_domain = email_domain(referee_subscription.user.email)

    # Skip domain check for common email providers
    common_providers = %w[gmail.com yahoo.com outlook.com hotmail.com icloud.com]
    return false if common_providers.include?(referrer_domain.downcase)

    referrer_domain.downcase == referee_domain.downcase
  end

  def email_domain(email)
    email.to_s.split("@").last.to_s
  end

  def ip_abuse?(referrer)
    return false if ip_address.blank?

    ip_hash = hash_ip(ip_address)

    # Check if same IP was used for a referral from this referrer within cooldown period
    Referral.where(
      referrer_subscription: referrer,
      referee_ip_hash: ip_hash
    ).where("created_at > ?", IP_COOLDOWN_HOURS.hours.ago).exists?
  end

  def already_referred?
    Referral.exists?(referee_subscription: referee_subscription)
  end

  def hash_ip(ip)
    Digest::SHA256.hexdigest(ip.to_s)
  end

  def create_referral(referrer)
    referral = Referral.new(
      referrer_subscription: referrer,
      referee_subscription: referee_subscription,
      site: referee_subscription.site,
      referee_ip_hash: (hash_ip(ip_address) if ip_address.present?),
      status: :pending
    )

    if referral.save
      schedule_confirmation_job(referral)
      success(referral)
    else
      error(referral.errors.full_messages.join(", "))
    end
  end

  def schedule_confirmation_job(referral)
    ConfirmReferralJob.set(wait: 24.hours).perform_later(referral.id)
  end

  def success(referral)
    { success: true, referral: referral }
  end

  def error(message)
    { success: false, error: message }
  end
end
