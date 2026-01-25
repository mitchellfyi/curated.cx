# frozen_string_literal: true

# Service for cross-network content aggregation.
# Used by root tenant homepage to display all network sites and content.
class NetworkFeedService
  class << self
    # Returns all enabled sites across ALL tenants (for network directory)
    # Excludes the root tenant's site (curated.cx shouldn't list itself)
    def sites_directory(tenant:)
      Rails.cache.fetch(cache_key("sites", "network"), expires_in: 5.minutes) do
        root_tenant = Tenant.find_by(slug: "root")

        Site.unscoped
            .joins(:tenant)
            .where(tenants: { status: :enabled })
            .where(status: :enabled)
            .where.not(tenant: root_tenant)
            .includes(:primary_domain, :tenant)
            .order(:name)
            .to_a
      end
    end

    # Returns recent content from ALL enabled sites across network
    # Excludes content from root tenant's site
    def recent_content(tenant:, limit: 20, offset: 0)
      Rails.cache.fetch(cache_key("content", "network", limit, offset), expires_in: 5.minutes) do
        root_tenant = Tenant.find_by(slug: "root")
        network_sites = Site.unscoped
                            .joins(:tenant)
                            .where(tenants: { status: :enabled })
                            .where(status: :enabled)
                            .where.not(tenant: root_tenant)

        ContentItem.unscoped
                   .where(site: network_sites)
                   .where.not(published_at: nil)
                   .where(hidden_at: nil)
                   .order(published_at: :desc)
                   .offset(offset)
                   .limit(limit)
                   .includes(:source, site: :primary_domain)
                   .to_a
      end
    end

    # Returns network-wide stats (all tenants except root)
    def network_stats(tenant:)
      Rails.cache.fetch(cache_key("stats", "network"), expires_in: 10.minutes) do
        root_tenant = Tenant.find_by(slug: "root")
        network_sites = Site.unscoped
                            .joins(:tenant)
                            .where(tenants: { status: :enabled })
                            .where(status: :enabled)
                            .where.not(tenant: root_tenant)
        site_ids = network_sites.pluck(:id)

        {
          site_count: network_sites.count,
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
