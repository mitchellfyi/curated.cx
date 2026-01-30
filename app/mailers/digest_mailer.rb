# frozen_string_literal: true

class DigestMailer < ApplicationMailer
  def weekly_digest(subscription)
    @subscription = subscription
    @user = subscription.user
    @site = subscription.site
    @tenant = @site.tenant

    @content_items = fetch_top_content(since: 1.week.ago, limit: 10)
    @listings = fetch_new_listings(since: 1.week.ago, limit: 5)
    @personalized_content = fetch_personalized_content(limit: 5)

    return if @content_items.empty? && @listings.empty?

    mail(
      to: @user.email,
      subject: I18n.t("digest_mailer.weekly_digest.subject", site: @site.name),
      from: digest_from_address
    )
  end

  def daily_digest(subscription)
    @subscription = subscription
    @user = subscription.user
    @site = subscription.site
    @tenant = @site.tenant

    @content_items = fetch_top_content(since: 1.day.ago, limit: 5)
    @listings = fetch_new_listings(since: 1.day.ago, limit: 3)
    @personalized_content = fetch_personalized_content(limit: 3)

    return if @content_items.empty? && @listings.empty?

    mail(
      to: @user.email,
      subject: I18n.t("digest_mailer.daily_digest.subject", site: @site.name),
      from: digest_from_address
    )
  end

  private

  def fetch_top_content(since:, limit:)
    ContentItem
      .where(site: @site)
      .published
      .not_hidden
      .where("published_at >= ?", since)
      .order(Arel.sql("(upvotes_count + comments_count) DESC, published_at DESC"))
      .limit(limit)
  end

  def fetch_new_listings(since:, limit:)
    Listing
      .where(site: @site)
      .published
      .where("published_at >= ?", since)
      .order(published_at: :desc)
      .limit(limit)
  end

  def fetch_personalized_content(limit:)
    return [] unless @user

    ContentRecommendationService.for_digest(@subscription, limit: limit)
  rescue StandardError => e
    Rails.logger.error("Failed to fetch personalized content for digest: #{e.message}")
    []
  end

  def digest_from_address
    site_email = @site.setting("email.from_address")
    return site_email if site_email.present?

    tenant_email = @tenant.setting("email.from_address")
    return tenant_email if tenant_email.present?

    "digest@#{@site.primary_hostname || 'curated.cx'}"
  end
end
