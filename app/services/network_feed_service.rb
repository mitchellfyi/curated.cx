# frozen_string_literal: true

class NetworkFeedService
  class << self
    def sites_directory(tenant:)
      Rails.cache.fetch(cache_key("sites", tenant.id), expires_in: 5.minutes) do
        Site.unscoped
            .where(tenant: tenant)
            .where(status: :enabled)
            .includes(:primary_domain, :tenant)
            .order(:name)
            .to_a
      end
    end

    def recent_content(tenant:, limit: 20, offset: 0)
      Rails.cache.fetch(cache_key("content", tenant.id, limit, offset), expires_in: 5.minutes) do
        sites = Site.unscoped.where(tenant: tenant).where(status: :enabled)

        ContentItem.unscoped
                   .where(site: sites)
                   .where.not(published_at: nil)
                   .where(hidden_at: nil)
                   .order(published_at: :desc)
                   .offset(offset)
                   .limit(limit)
                   .includes(:source, site: :primary_domain)
                   .to_a
      end
    end

    def network_stats(tenant:)
      Rails.cache.fetch(cache_key("stats", tenant.id), expires_in: 10.minutes) do
        sites = Site.unscoped.where(tenant: tenant).where(status: :enabled)
        site_ids = sites.pluck(:id)

        {
          site_count: sites.count,
          content_count: ContentItem.unscoped.where(site_id: site_ids).where.not(published_at: nil).count,
          listing_count: Listing.unscoped.where(site_id: site_ids).where.not(published_at: nil).count
        }
      end
    end

    private

    def cache_key(*parts)
      [ "network_feed", *parts ].join(":")
    end
  end
end
