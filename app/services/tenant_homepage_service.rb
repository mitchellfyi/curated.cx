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
      categories_with_entries: categories_with_recent_entries
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

  def categories_with_recent_entries
    # Fetch categories with published entries in a single query
    categories = Category.where(site: @site)
                         .joins(:entries)
                         .where(entries: { site: @site })
                         .where.not(entries: { published_at: nil })
                         .distinct
                         .order(:name)
                         .to_a

    return [] if categories.empty?

    # Fetch top 4 entries per category in a single query using window function
    # This avoids N+1 by getting all entries at once
    category_ids = categories.map(&:id)
    entries_by_category = Entry.directory_items.where(site: @site, category_id: category_ids)
                                  .where.not(published_at: nil)
                                  .order(category_id: :asc, published_at: :desc)
                                  .to_a
                                  .group_by(&:category_id)
                                  .transform_values { |entries| entries.first(4) }

    categories.filter_map do |category|
      entries = entries_by_category[category.id] || []
      [ category, entries ] if entries.any?
    end
  end
end
