# frozen_string_literal: true

# Service for tracking boost clicks and attributing conversions.
# Handles click recording, IP deduplication, and conversion attribution.
class BoostAttributionService
  ATTRIBUTION_WINDOW = 30.days
  DEDUP_WINDOW = 24.hours

  class << self
    include IpHashable

    # Record a click on a boost
    # Returns the BoostClick if created, nil if deduplicated
    def record_click(boost:, ip:)
      ip_hash = hash_ip(ip)

      # Deduplicate clicks from same IP within 24h window
      if recently_clicked?(boost: boost, ip_hash: ip_hash)
        return nil
      end

      click = BoostClick.create!(
        network_boost: boost,
        ip_hash: ip_hash,
        clicked_at: Time.current,
        earned_amount: boost.cpc_rate
      )

      # Update boost spending
      boost.record_click!

      # Schedule confirmation job for 24h later
      ConfirmBoostClickJob.set(wait: 24.hours).perform_later(click.id)

      click
    end

    # Attribute a conversion (subscription) to a previous click
    # Uses 30-day attribution window
    def attribute_conversion(subscription:, ip:)
      ip_hash = hash_ip(ip)
      target_site = subscription.site

      # Find the most recent unconverted click from this IP to the target site
      click = find_attributable_click(ip_hash: ip_hash, target_site: target_site)
      return nil if click.nil?

      click.mark_converted!(subscription)
      click
    end

    # Calculate earnings for a site in a period (as the referrer/source)
    def calculate_earnings(site:, start_date:, end_date:)
      BoostClick
        .joins(:network_boost)
        .where(network_boosts: { source_site_id: site.id })
        .where(status: [ :confirmed, :paid ])
        .where(clicked_at: start_date..end_date)
        .sum(:earned_amount)
    end

    # Calculate spend for a site in a period (as the target being promoted)
    def calculate_spend(site:, start_date:, end_date:)
      BoostClick
        .joins(:network_boost)
        .where(network_boosts: { target_site_id: site.id })
        .where(status: [ :confirmed, :paid ])
        .where(clicked_at: start_date..end_date)
        .sum(:earned_amount)
    end

    # Get stats for a boost
    def boost_stats(boost, since: 30.days.ago)
      clicks = boost.boost_clicks.where(clicked_at: since..)
      impressions = boost.boost_impressions.where(shown_at: since..)

      {
        impressions: impressions.count,
        clicks: clicks.count,
        conversions: clicks.converted.count,
        click_rate: impressions.any? ? (clicks.count.to_f / impressions.count * 100).round(2) : 0,
        conversion_rate: clicks.any? ? (clicks.converted.count.to_f / clicks.count * 100).round(2) : 0,
        earnings: clicks.sum(:earned_amount)
      }
    end

    private

    def recently_clicked?(boost:, ip_hash:)
      return false if ip_hash.nil?

      BoostClick
        .where(network_boost: boost, ip_hash: ip_hash)
        .where(clicked_at: DEDUP_WINDOW.ago..)
        .exists?
    end

    def find_attributable_click(ip_hash:, target_site:)
      return nil if ip_hash.nil?

      BoostClick
        .joins(:network_boost)
        .where(network_boosts: { target_site_id: target_site.id })
        .where(ip_hash: ip_hash)
        .where(clicked_at: ATTRIBUTION_WINDOW.ago..)
        .where(converted_at: nil)
        .order(clicked_at: :desc)
        .first
    end
  end
end
