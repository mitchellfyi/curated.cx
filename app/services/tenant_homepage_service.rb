# frozen_string_literal: true

class TenantHomepageService
  def initialize(site:, tenant:)
    @site = site
    @tenant = tenant
  end

  def root_tenant_data
    {
      sites: NetworkFeedService.sites_directory(tenant: @tenant),
      trending_sites: NetworkFeedService.trending_sites(tenant: @tenant, limit: 6),
      new_sites: NetworkFeedService.new_sites(tenant: @tenant, limit: 6),
      network_feed: NetworkFeedService.recent_content(tenant: @tenant, limit: 12),
      network_notes: NetworkFeedService.recent_notes(tenant: @tenant, limit: 6),
      network_stats: NetworkFeedService.network_stats(tenant: @tenant)
    }
  end

  def tenant_data
    {
      content_items: content_items_feed,
      categories_with_listings: categories_with_recent_listings
    }
  end

  # Generate personalized content recommendations for a user.
  # Returns nil if user is nil, empty array if an error occurs.
  def personalized_content(user)
    return nil unless user

    ContentRecommendationService.for_user(user, site: @site, limit: 6)
  rescue StandardError => e
    Rails.logger.error("Failed to generate personalized content: #{e.message}")
    []
  end

  private

  def content_items_feed
    FeedRankingService.ranked_feed(
      site: @site,
      filters: {},
      limit: 12,
      offset: 0
    )
  end

  def categories_with_recent_listings
    # Fetch categories with published listings in a single query
    categories = Category.where(site: @site)
                         .joins(:listings)
                         .where(listings: { site: @site })
                         .where.not(listings: { published_at: nil })
                         .distinct
                         .order(:name)
                         .to_a

    return [] if categories.empty?

    # Fetch top 4 listings per category in a single query using window function
    # This avoids N+1 by getting all listings at once
    category_ids = categories.map(&:id)
    listings_by_category = Listing.where(site: @site, category_id: category_ids)
                                  .where.not(published_at: nil)
                                  .order(category_id: :asc, published_at: :desc)
                                  .to_a
                                  .group_by(&:category_id)
                                  .transform_values { |listings| listings.first(4) }

    categories.filter_map do |category|
      listings = listings_by_category[category.id] || []
      [ category, listings ] if listings.any?
    end
  end
end
