# frozen_string_literal: true

class Admin::AffiliateClicksController < ApplicationController
  include AdminAccess

  def index
    @period = params[:period] || "30d"
    @category_id = params[:category_id]

    @date_range = parse_period(@period)
    @clicks = base_scope.where(clicked_at: @date_range)

    @stats = calculate_stats
    @daily_clicks = calculate_daily_clicks
    @top_entries = calculate_top_entries(limit: 10)
    @categories = Category.order(:name)

    set_page_meta_tags(
      title: t("admin.affiliate_clicks.title"),
      description: t("admin.affiliate_clicks.description")
    )
  end

  def export
    @period = params[:period] || "30d"
    @category_id = params[:category_id]
    @date_range = parse_period(@period)

    @clicks = base_scope
              .where(clicked_at: @date_range)
              .includes(entry: :category)
              .order(clicked_at: :desc)

    respond_to do |format|
      format.csv do
        send_data generate_csv(@clicks),
                  filename: "affiliate_clicks_#{Date.current}.csv",
                  type: "text/csv"
      end
    end
  end

  private

  def base_scope
    scope = AffiliateClick.joins(:entry).where(entries: { site_id: Current.site&.id })
    scope = scope.where(entries: { category_id: @category_id }) if @category_id.present?
    scope
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
    {
      total_clicks: @clicks.count,
      unique_entries: @clicks.distinct.count(:entry_id),
      clicks_today: @clicks.where(clicked_at: Time.current.beginning_of_day..).count,
      clicks_this_week: @clicks.where(clicked_at: 1.week.ago..).count
    }
  end

  def calculate_daily_clicks
    @clicks
      .group_by_day(:clicked_at, time_zone: Time.zone)
      .count
  end

  def calculate_top_entries(limit:)
    entry_ids_with_counts = @clicks
                            .group(:entry_id)
                            .order(Arel.sql("COUNT(*) DESC"))
                            .limit(limit)
                            .pluck(:entry_id, Arel.sql("COUNT(*)"))

    entry_ids = entry_ids_with_counts.map(&:first)
    entries_by_id = Entry.where(id: entry_ids).includes(:category).index_by(&:id)

    entry_ids_with_counts.map do |entry_id, count|
      {
        entry: entries_by_id[entry_id],
        click_count: count
      }
    end.compact_blank
  end

  def generate_csv(clicks)
    CSV.generate(headers: true) do |csv|
      csv << [ "Date", "Entry", "Category", "URL", "Referrer", "User Agent" ]

      clicks.find_each do |click|
        csv << [
          click.clicked_at.strftime("%Y-%m-%d %H:%M:%S"),
          click.entry.title,
          click.entry.category&.name,
          click.entry.url_canonical,
          click.referrer,
          click.user_agent
        ]
      end
    end
  end
end
