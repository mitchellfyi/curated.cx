# frozen_string_literal: true

# Service for cross-network content aggregation.
# Used by root tenant homepage to display all network sites and content.
class NetworkFeedService
  class << self
    # Returns all enabled sites across ALL tenants (for network directory)
    # Excludes the root tenant's site (curated.cx shouldn't list itself)
    def sites_directory(tenant:)
      Rails.cache.fetch(cache_key("sites", "network"), expires_in: 5.minutes) do
        network_sites_scope
            .includes(:primary_domain, :tenant)
            .order(:name)
            .to_a
      end
    end

    # Returns recent content from ALL enabled sites across network
    # Excludes content from root tenant's site
    def recent_content(tenant:, limit: 20, offset: 0)
      Rails.cache.fetch(cache_key("content", "network", limit, offset), expires_in: 5.minutes) do
        recent_publishable_items(
          model_class: Entry,
          includes: [ :source, site: :primary_domain ],
          limit: limit,
          offset: offset
        )
      end
    end

    # Returns trending sites based on recent subscriber growth
    def trending_sites(tenant:, limit: 6)
      Rails.cache.fetch(cache_key("trending_sites", limit), expires_in: 15.minutes) do
        # Get site IDs ranked by recent subscriptions using subquery
        site_ids = network_sites_scope
            .joins("LEFT JOIN digest_subscriptions ON digest_subscriptions.site_id = sites.id AND digest_subscriptions.created_at > '#{30.days.ago.to_fs(:db)}'")
            .group("sites.id")
            .order("COUNT(digest_subscriptions.id) DESC")
            .limit(limit)
            .pluck(:id)

        # Load sites with associations using the ordered IDs
        Site.unscoped
            .where(id: site_ids)
            .includes(:primary_domain, :tenant)
            .index_by(&:id)
            .values_at(*site_ids)
            .compact
      end
    end

    # Returns newly created sites
    def new_sites(tenant:, limit: 6)
      Rails.cache.fetch(cache_key("new_sites", limit), expires_in: 15.minutes) do
        network_sites_scope
            .where(created_at: 90.days.ago..)
            .includes(:primary_domain, :tenant)
            .order(created_at: :desc)
            .limit(limit)
            .to_a
      end
    end

    # Returns sites filtered by topic
    def sites_by_topic(tenant:, topic:, limit: 10)
      Rails.cache.fetch(cache_key("sites_by_topic", topic, limit), expires_in: 10.minutes) do
        network_sites_scope
            .where("config->'topics' ? :topic", topic: topic)
            .includes(:primary_domain, :tenant)
            .order(:name)
            .limit(limit)
            .to_a
      end
    end

    # Returns recent notes from ALL enabled sites across network
    # Excludes notes from root tenant's site
    def recent_notes(tenant:, limit: 20, offset: 0)
      Rails.cache.fetch(cache_key("notes", "network", limit, offset), expires_in: 5.minutes) do
        recent_publishable_items(
          model_class: Note,
          includes: [ :user, site: :primary_domain ],
          limit: limit,
          offset: offset
        )
      end
    end

    # Returns network-wide stats (all tenants except root)
    def network_stats(tenant:)
      Rails.cache.fetch(cache_key("stats", "network"), expires_in: 10.minutes) do
        site_ids = network_sites_scope.pluck(:id)

        {
          site_count: network_sites_scope.count,
          content_count: Entry.unscoped.where(entry_kind: "feed", site_id: site_ids).where.not(published_at: nil).count,
          listing_count: Entry.unscoped.where(entry_kind: "directory", site_id: site_ids).where.not(published_at: nil).count,
          note_count: Note.unscoped.where(site_id: site_ids).where.not(published_at: nil).count
        }
      end
    end

    private

    def cache_key(*parts)
      [ "network_feed", *parts ].join(":")
    end

    def root_tenant
      Tenant.find_by(slug: "root")
    end

    def network_sites_scope
      Site.unscoped
          .joins(:tenant)
          .where(tenants: { status: :enabled })
          .where(status: :enabled)
          .where.not(tenant: root_tenant)
    end

    def recent_publishable_items(model_class:, includes:, limit:, offset:)
      scope = model_class.unscoped
      scope = scope.feed_items if model_class == Entry
      scope.where(site: network_sites_scope)
           .where.not(published_at: nil)
           .where(hidden_at: nil)
           .order(published_at: :desc)
           .offset(offset)
           .limit(limit)
           .includes(includes)
           .to_a
    end
  end
end
