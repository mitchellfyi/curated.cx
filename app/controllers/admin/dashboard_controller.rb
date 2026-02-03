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
    {
      users: User.count,
      users_this_week: User.where("created_at > ?", 1.week.ago).count,
      content_items: ContentItem.count,
      notes: Note.count,
      comments: Comment.count,
      submissions_pending: Submission.pending.count,
      flags_open: Flag.open.count,
      sources_enabled: Source.enabled.count,
      imports_today: ImportRun.where("started_at > ?", Time.current.beginning_of_day).count,
      imports_failed_today: ImportRun.failed.where("started_at > ?", Time.current.beginning_of_day).count
    }
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

  def categories_service
    @categories_service ||= Admin::CategoriesService.new(Current.tenant)
  end

  def listings_service
    @listings_service ||= Admin::ListingsService.new(Current.tenant)
  end
end
