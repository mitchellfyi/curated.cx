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

  def categories_service
    @categories_service ||= Admin::CategoriesService.new(Current.tenant)
  end

  def listings_service
    @listings_service ||= Admin::ListingsService.new(Current.tenant)
  end
end
