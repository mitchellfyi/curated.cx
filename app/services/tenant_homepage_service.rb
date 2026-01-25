# frozen_string_literal: true

class TenantHomepageService
  def initialize(site:, tenant:)
    @site = site
    @tenant = tenant
  end

  def root_tenant_data
    {
      sites: NetworkFeedService.sites_directory(tenant: @tenant),
      network_feed: NetworkFeedService.recent_content(tenant: @tenant, limit: 12),
      network_stats: NetworkFeedService.network_stats(tenant: @tenant)
    }
  end

  def tenant_data
    {
      content_items: content_items_feed,
      categories_with_listings: categories_with_recent_listings
    }
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
    categories = Category.where(site: @site)
                         .joins(:listings)
                         .where(listings: { site: @site })
                         .where.not(listings: { published_at: nil })
                         .distinct
                         .order(:name)

    categories.map do |category|
      listings = category.listings
                         .where(site: @site)
                         .where.not(published_at: nil)
                         .order(published_at: :desc)
                         .limit(4)
      [ category, listings ]
    end.reject { |_cat, listings| listings.empty? }
  end
end
