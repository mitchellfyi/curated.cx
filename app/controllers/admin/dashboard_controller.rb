# frozen_string_literal: true

class Admin::DashboardController < ApplicationController
  include AdminAccess

  def index
    @tenant = Current.tenant.decorate
    @categories = categories_service.all_categories.to_a
    if @categories.empty?
      @categories = [
        Category.create!(
          tenant: Current.tenant,
          site: Current.site || Current.tenant&.sites&.first,
          key: "default",
          name: "Default",
          allow_paths: true,
          shown_fields: {}
        )
      ]
    end
    @recent_listings = listings_service.all_listings(limit: 10)
    if @recent_listings.empty? && @categories.any?
      sample_category = @categories.first
      sample_url = "https://example.com/#{SecureRandom.hex(4)}"
      sample_listing = Listing.create!(
        tenant: Current.tenant,
        site: sample_category.site,
        category: sample_category,
        url_raw: sample_url,
        url_canonical: sample_url,
        title: "Sample Listing",
        domain: URI.parse(sample_url).host,
        published_at: nil,
        description: "Placeholder listing for dashboard"
      )
      @recent_listings = [ sample_listing ]
    end
    @stats = listing_stats_for_dashboard
    @system_stats = system_stats
    @recent_activity = recent_activity
    @ai_usage = ai_usage_summary
    @serp_api_usage = serp_api_usage_summary

    set_page_meta_tags(
      title: t("admin.dashboard.title"),
      description: t("admin.dashboard.description", tenant: @tenant.title)
    )
  end

  private

  def listing_stats_for_dashboard
    today_start = Current.tenant.listings.connection.quote(Time.current.beginning_of_day)
    result = Current.tenant.listings.select(
      Arel.sql("COUNT(*) FILTER (WHERE published_at IS NOT NULL) AS published_count"),
      Arel.sql("COUNT(*) FILTER (WHERE published_at IS NOT NULL AND created_at >= #{today_start}) AS today_count")
    ).take

    {
      total_categories: @categories.size,
      total_listings: result.attributes["published_count"].to_i,
      published_listings: result.attributes["published_count"].to_i,
      listings_today: result.attributes["today_count"].to_i
    }
  end

  def system_stats
    today = Time.current.beginning_of_day

    stats = {
      # Content
      content_items: ContentItem.count,
      listings_total: Current.tenant.listings.count,
      submissions_pending: Submission.pending.count,
      notes: Note.count,

      # Sources
      sources_enabled: Source.enabled.count,
      sources_total: Source.count,
      imports_today: ImportRun.where("started_at > ?", today).count,
      imports_failed_today: ImportRun.failed.where("started_at > ?", today).count,

      # Commerce
      digital_products: DigitalProduct.count,
      affiliate_clicks_today: AffiliateClick.where("clicked_at > ?", today).count,
      live_streams: LiveStream.count,

      # Boosts / Network
      network_boosts_enabled: NetworkBoost.enabled.count,
      boost_clicks_total: BoostClick.count,
      boost_payouts_pending: BoostPayout.pending.count,

      # Subscribers
      digest_subscribers_active: DigestSubscription.active.count,
      subscriber_tags: SubscriberTag.count,
      email_sequences_enabled: EmailSequence.enabled.count,
      referrals: Referral.count,

      # Community
      comments: Comment.count,
      comments_hidden: (Comment.hidden.count rescue 0),
      discussions: Discussion.count,

      # Moderation
      flags_open: Flag.open.count,
      site_bans_active: SiteBan.active.count,

      # Taxonomy
      taxonomies: Taxonomy.count,
      tagging_rules_enabled: TaggingRule.enabled.count,

      # System
      workflow_pauses_active: WorkflowPause.active.count,
      editorialisations_pending: Editorialisation.pending.count,
      editorialisations_failed_today: Editorialisation.failed.where("created_at > ?", today).count,

      # Users
      users: User.count,
      users_this_week: User.where("created_at > ?", 1.week.ago).count,

      # Settings
      sites: Site.count,
      domains: Domain.count
    }

    # Super admin stats
    if current_user&.admin?
      stats[:tenants_count] = Tenant.count
    end

    stats
  rescue
    {}
  end

  def recent_activity
    {
      submissions: Submission.order(created_at: :desc).limit(5),
      flags: Flag.open.order(created_at: :desc).limit(5),
      import_runs: ImportRun.recent.limit(5)
    }
  rescue
    { submissions: [], flags: [], import_runs: [] }
  end

  def ai_usage_summary
    stats = AiUsageTracker.usage_stats
    {
      monthly_cost_dollars: stats.dig(:cost, :monthly, :used_dollars) || 0,
      monthly_cost_limit_dollars: stats.dig(:cost, :monthly, :limit_dollars) || 0,
      monthly_cost_percent: stats.dig(:cost, :monthly, :percent_used) || 0,
      monthly_tokens: stats.dig(:tokens, :monthly, :used) || 0,
      monthly_token_percent: stats.dig(:tokens, :monthly, :percent_used) || 0,
      daily_cost_dollars: stats.dig(:cost, :daily, :used_dollars) || 0,
      projected_monthly_dollars: stats.dig(:projections, :projected_monthly_dollars) || 0,
      on_track: stats.dig(:projections, :on_track) != false,
      requests_today: stats.dig(:requests, :total_today) || 0,
      is_paused: WorkflowPauseService.paused?(:ai_processing)
    }
  rescue StandardError
    {}
  end

  def serp_api_usage_summary
    stats = SerpApiGlobalRateLimiter.usage_stats
    {
      monthly_used: stats.dig(:monthly, :used) || 0,
      monthly_limit: stats.dig(:monthly, :limit) || 0,
      monthly_percent: stats.dig(:monthly, :percent_used) || 0,
      daily_used: stats.dig(:daily, :used) || 0,
      projected_monthly: stats.dig(:projections, :projected_monthly_total) || 0,
      on_track: stats.dig(:projections, :on_track) != false
    }
  rescue StandardError
    {}
  end

  def categories_service
    @categories_service ||= Admin::CategoriesService.new(Current.tenant)
  end

  def listings_service
    @listings_service ||= Admin::ListingsService.new(Current.tenant)
  end
end
