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
    @system_stats = system_stats
    @stats = {
      total_categories: @categories.size,
      total_listings: @system_stats[:published_listings].to_i,
      published_listings: @system_stats[:published_listings].to_i,
      listings_today: @system_stats[:listings_today].to_i
    }
    @recent_activity = recent_activity
    @ai_usage = ai_usage_summary
    @serp_api_usage = serp_api_usage_summary

    set_page_meta_tags(
      title: t("admin.dashboard.title"),
      description: t("admin.dashboard.description", tenant: @tenant.title)
    )
  end

  private

  def system_stats
    today = Time.current.beginning_of_day

    # Build a single SQL query from model scopes for all dashboard counts
    counts = {
      content_items: ContentItem.all,
      listings_total: Current.tenant.listings,
      published_listings: Current.tenant.listings.where.not(published_at: nil),
      listings_today: Current.tenant.listings.where.not(published_at: nil).where("created_at >= ?", today),
      submissions_pending: Submission.pending,
      notes: Note.all,
      sources_enabled: Source.enabled,
      sources_total: Source.all,
      imports_today: ImportRun.where("started_at > ?", today),
      imports_failed_today: ImportRun.failed.where("started_at > ?", today),
      digital_products: DigitalProduct.all,
      affiliate_clicks_today: AffiliateClick.where("clicked_at > ?", today),
      live_streams: LiveStream.all,
      network_boosts_enabled: NetworkBoost.enabled,
      boost_clicks_total: BoostClick.all,
      boost_payouts_pending: BoostPayout.pending,
      digest_subscribers_active: DigestSubscription.active,
      subscriber_tags: SubscriberTag.all,
      email_sequences_enabled: EmailSequence.enabled,
      referrals: Referral.all,
      comments: Comment.all,
      comments_hidden: Comment.hidden,
      discussions: Discussion.all,
      flags_open: Flag.open,
      site_bans_active: SiteBan.active,
      taxonomies: Taxonomy.all,
      tagging_rules_enabled: TaggingRule.enabled,
      workflow_pauses_active: WorkflowPause.active,
      editorialisations_pending: Editorialisation.pending,
      editorialisations_failed_today: Editorialisation.failed.where("created_at > ?", today),
      users: User.unscoped,
      users_this_week: User.unscoped.where("created_at > ?", 1.week.ago),
      sites: Site.all,
      domains: Domain.joins(:site).where(sites: { tenant_id: Current.tenant.id })
    }

    subqueries = counts.map { |key, scope| "(#{scope.select('COUNT(*)').to_sql}) AS #{key}" }
    sql = "SELECT #{subqueries.join(', ')}"
    row = ActiveRecord::Base.connection.select_one(sql)

    stats = row.transform_keys(&:to_sym).transform_values(&:to_i)
    stats[:tenants_count] = Tenant.count if current_user&.admin?

    stats
  rescue StandardError
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
