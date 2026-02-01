# frozen_string_literal: true

# Service for selecting and displaying network boosts.
# Determines which boosts to show on a given site based on eligibility,
# budget, and user subscriptions.
class NetworkBoostService
  class << self
    include IpHashable

    # Returns eligible boosts to display on the given site
    # Excludes: current site, sites user is subscribed to, boosts over budget
    def for_site(site, user: nil, limit: 3)
      return [] unless site.boosts_display_enabled?

      subscribed_site_ids = user_subscribed_site_ids(user)

      NetworkBoost
        .enabled
        .with_budget
        .where(target_site: site)
        .where.not(source_site_id: site.id)
        .where.not(source_site_id: subscribed_site_ids)
        .includes(source_site: :primary_domain)
        .order(cpc_rate: :desc)
        .limit(limit)
        .to_a
    end

    # Returns boosts available for a site to promote (where they are the source)
    def available_targets(site, limit: 10)
      existing_target_ids = site.boosts_as_source.pluck(:target_site_id)

      Site.unscoped
          .where(status: :enabled)
          .where.not(id: site.id)
          .where.not(id: existing_target_ids)
          .includes(:primary_domain)
          .order(:name)
          .limit(limit)
          .to_a
    end

    # Record an impression for a boost shown on a site
    def record_impression(boost:, site:, ip:)
      ip_hash = hash_ip(ip)

      BoostImpression.create!(
        network_boost: boost,
        site: site,
        ip_hash: ip_hash,
        shown_at: Time.current
      )
    end

    # Batch record impressions for multiple boosts
    def record_impressions(boosts:, site:, ip:)
      return if boosts.empty?

      ip_hash = hash_ip(ip)
      now = Time.current

      impressions = boosts.map do |boost|
        {
          network_boost_id: boost.id,
          site_id: site.id,
          ip_hash: ip_hash,
          shown_at: now,
          created_at: now,
          updated_at: now
        }
      end

      BoostImpression.insert_all(impressions)
    end

    private

    def user_subscribed_site_ids(user)
      return [] if user.nil?

      DigestSubscription.unscoped
                        .where(user: user)
                        .where(active: true)
                        .pluck(:site_id)
    end
  end
end
