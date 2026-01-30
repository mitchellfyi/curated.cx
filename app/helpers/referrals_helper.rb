# frozen_string_literal: true

module ReferralsHelper
  def twitter_share_url(referral_link, site_name)
    text = I18n.t("referrals.share_text.twitter", site: site_name)
    "https://twitter.com/intent/tweet?text=#{ERB::Util.url_encode(text)}&url=#{ERB::Util.url_encode(referral_link)}"
  end

  def linkedin_share_url(referral_link)
    "https://www.linkedin.com/sharing/share-offsite/?url=#{ERB::Util.url_encode(referral_link)}"
  end

  def email_share_url(referral_link, site_name)
    subject = I18n.t("referrals.share_text.email_subject", site: site_name)
    body = I18n.t("referrals.share_text.email_body", link: referral_link, site: site_name)
    "mailto:?subject=#{ERB::Util.url_encode(subject)}&body=#{ERB::Util.url_encode(body)}"
  end
end
