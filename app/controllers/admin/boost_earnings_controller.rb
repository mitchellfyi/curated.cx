# frozen_string_literal: true

class Admin::BoostEarningsController < ApplicationController
  include AdminAccess

  def index
    @period = params[:period] || "30d"
    @date_range = parse_period(@period)

    @stats = calculate_stats
    @daily_clicks = calculate_daily_clicks
    @top_boosts = calculate_top_boosts(limit: 10)

    set_page_meta_tags(
      title: t("admin.boost_earnings.title"),
      description: t("admin.boost_earnings.description")
    )
  end

  def export
    @period = params[:period] || "30d"
    @date_range = parse_period(@period)

    @clicks = earning_clicks_scope
              .includes(network_boost: [ :source_site, :target_site ])
              .order(clicked_at: :desc)

    respond_to do |format|
      format.csv do
        send_data generate_csv(@clicks),
                  filename: "boost_earnings_#{Date.current}.csv",
                  type: "text/csv"
      end
    end
  end

  private

  # Earnings come from clicks where Current.site is the SOURCE (they promote others)
  def earning_clicks_scope
    BoostClick
      .joins(:network_boost)
      .where(network_boosts: { source_site_id: Current.site&.id })
      .where(clicked_at: @date_range)
  end

  def parse_period(period)
    case period
    when "7d"
      7.days.ago..Time.current
    when "30d"
      30.days.ago..Time.current
    when "90d"
      90.days.ago..Time.current
    when "365d"
      1.year.ago..Time.current
    else
      30.days.ago..Time.current
    end
  end

  def calculate_stats
    clicks = earning_clicks_scope
    confirmed_clicks = clicks.where(status: [ :confirmed, :paid ])

    impressions = BoostImpression
                  .joins(:network_boost)
                  .where(network_boosts: { source_site_id: Current.site&.id })
                  .where(shown_at: @date_range)

    {
      total_impressions: impressions.count,
      total_clicks: clicks.count,
      conversions: clicks.converted.count,
      pending_earnings: clicks.pending.sum(:earned_amount) || 0,
      confirmed_earnings: confirmed_clicks.sum(:earned_amount) || 0,
      total_earnings: clicks.sum(:earned_amount) || 0,
      click_rate: impressions.any? ? (clicks.count.to_f / impressions.count * 100).round(2) : 0,
      conversion_rate: clicks.any? ? (clicks.converted.count.to_f / clicks.count * 100).round(2) : 0
    }
  end

  def calculate_daily_clicks
    earning_clicks_scope
      .group_by_day(:clicked_at, time_zone: Time.zone)
      .count
  end

  def calculate_top_boosts(limit:)
    boost_stats = earning_clicks_scope
                  .group(:network_boost_id)
                  .select("network_boost_id, COUNT(*) as click_count, SUM(earned_amount) as earnings")
                  .order(Arel.sql("COUNT(*) DESC"))
                  .limit(limit)

    boost_ids = boost_stats.map(&:network_boost_id)
    boosts_by_id = NetworkBoost.where(id: boost_ids).includes(target_site: :primary_domain).index_by(&:id)

    boost_stats.map do |stat|
      boost = boosts_by_id[stat.network_boost_id]
      next unless boost

      {
        boost: boost,
        click_count: stat.click_count,
        earnings: stat.earnings || 0
      }
    end.compact
  end

  def generate_csv(clicks)
    CSV.generate(headers: true) do |csv|
      csv << [ "Date", "Target Site", "Status", "Converted", "Earned Amount" ]

      clicks.find_each do |click|
        csv << [
          click.clicked_at.strftime("%Y-%m-%d %H:%M:%S"),
          click.network_boost.target_site.name,
          click.status,
          click.converted_at ? "Yes" : "No",
          click.earned_amount
        ]
      end
    end
  end
end
