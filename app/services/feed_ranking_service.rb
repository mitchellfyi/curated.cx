# frozen_string_literal: true

# Service to rank content items for the public feed.
# Combines freshness decay, source quality, and engagement signals.
#
# Usage:
#   FeedRankingService.ranked_feed(site:, filters: {}, limit: 20, offset: 0)
#   # => ActiveRecord::Relation of ContentItems ordered by score
#
class FeedRankingService
  # Ranking weights - must sum to 1.0
  FRESHNESS_WEIGHT = 0.4
  SOURCE_QUALITY_WEIGHT = 0.3
  ENGAGEMENT_WEIGHT = 0.3

  # Freshness decay parameters
  DECAY_HALF_LIFE_HOURS = 24 # Score halves every 24 hours

  # Sort modes
  SORT_RANKED = "ranked"
  SORT_LATEST = "latest"
  SORT_TOP_WEEK = "top_week"
  VALID_SORTS = [ SORT_RANKED, SORT_LATEST, SORT_TOP_WEEK ].freeze

  def self.ranked_feed(site:, filters: {}, limit: 20, offset: 0)
    new(site, filters).ranked_feed(limit: limit, offset: offset)
  end

  def initialize(site, filters = {})
    @site = site
    @filters = filters.symbolize_keys
  end

  def ranked_feed(limit: 20, offset: 0)
    base_scope = build_base_scope
    sorted_scope = apply_sort(base_scope)
    sorted_scope.limit(limit).offset(offset)
  end

  private

  def build_base_scope
    scope = ContentItem.where(site: @site).published

    # Filter by tag
    if @filters[:tag].present?
      scope = scope.tagged_with(@filters[:tag])
    end

    # Filter by content type
    if @filters[:content_type].present?
      scope = scope.by_content_type(@filters[:content_type])
    end

    scope
  end

  def apply_sort(scope)
    sort = @filters[:sort] || SORT_RANKED

    case sort.to_s
    when SORT_LATEST
      scope.order(published_at: :desc)
    when SORT_TOP_WEEK
      # Safe SQL: engagement_score_sql uses only column names, no user input
      # brakeman:disable SQL
      scope.published_since(1.week.ago)
           .order(Arel.sql(engagement_score_sql + " DESC, published_at DESC"))
    when SORT_RANKED
      # Safe SQL: ranking_score_sql uses only constants and column names, no user input
      # brakeman:disable SQL
      scope.joins(:source)
           .order(Arel.sql(ranking_score_sql + " DESC"))
    else
      scope.order(published_at: :desc)
    end
  end

  def ranking_score_sql
    <<~SQL.squish
      (
        #{freshness_score_sql} * #{FRESHNESS_WEIGHT} +
        COALESCE(sources.quality_weight, 1.0) * #{SOURCE_QUALITY_WEIGHT} +
        #{normalized_engagement_sql} * #{ENGAGEMENT_WEIGHT}
      )
    SQL
  end

  def freshness_score_sql
    # Exponential decay: score = 1 / (1 + hours_ago / half_life)
    # This gives 1.0 for brand new, 0.5 after 24 hours, etc.
    <<~SQL.squish
      (1.0 / (1.0 + EXTRACT(EPOCH FROM (NOW() - content_items.published_at)) / 3600.0 / #{DECAY_HALF_LIFE_HOURS}))
    SQL
  end

  def engagement_score_sql
    # Raw engagement: upvotes + comments * 0.5
    "(content_items.upvotes_count + content_items.comments_count * 0.5)"
  end

  def normalized_engagement_sql
    # Normalized engagement: divide by max to get 0-1 range
    # Uses subquery to find max engagement in the site
    # Falls back to 1 if max is 0 to avoid division by zero
    max_engagement_subquery = ContentItem.where(site: @site)
                                         .select("MAX(upvotes_count + comments_count * 0.5)")
                                         .to_sql

    <<~SQL.squish
      CASE
        WHEN (#{max_engagement_subquery}) > 0
        THEN #{engagement_score_sql} / (#{max_engagement_subquery})
        ELSE 0
      END
    SQL
  end
end
