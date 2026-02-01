# frozen_string_literal: true

# Service to generate personalized content recommendations for users.
# Uses content-based filtering on topic_tags with signals from votes, bookmarks, and views.
#
# Usage:
#   ContentRecommendationService.for_user(user, site:, limit: 6)
#   ContentRecommendationService.similar_to(content_item, limit: 4)
#   ContentRecommendationService.for_digest(subscription, limit: 5)
#
class ContentRecommendationService
  # Interaction weights for computing topic affinity
  VOTE_WEIGHT = 3.0
  BOOKMARK_WEIGHT = 2.0
  VIEW_WEIGHT = 1.0

  # Time decay parameters (half-life in days)
  DECAY_HALF_LIFE_DAYS = 14

  # Cold start threshold - minimum interactions for personalization
  COLD_START_THRESHOLD = 5

  # Lookback window for interaction history
  LOOKBACK_DAYS = 90

  # Diversity ratio - percentage of results from trending/engagement
  DIVERSITY_RATIO = 0.2

  # Maximum interactions to consider (for performance)
  MAX_INTERACTIONS = 100

  def self.for_user(user, site:, limit: 6)
    new(site: site).for_user(user, limit: limit)
  end

  def self.similar_to(content_item, limit: 4)
    new(site: content_item.site).similar_to(content_item, limit: limit)
  end

  def self.for_digest(subscription, limit: 5)
    new(site: subscription.site).for_digest(subscription, limit: limit)
  end

  def initialize(site:)
    @site = site
  end

  # Generate personalized recommendations for a user.
  # Returns cold start fallback if user has insufficient interactions.
  def for_user(user, limit: 6)
    return cold_start_fallback(limit) unless user

    cache_key = "recommendations/user/#{user.id}/site/#{@site.id}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      compute_recommendations_for_user(user, limit)
    end
  end

  # Find content similar to a given content item based on topic_tags.
  def similar_to(content_item, limit: 4)
    return [] if content_item.topic_tags.blank?

    ContentItem
      .where(site: @site)
      .published
      .where.not(id: content_item.id)
      .where("topic_tags ?| array[:tags]", tags: content_item.topic_tags)
      .order(published_at: :desc)
      .limit(limit)
  end

  # Generate recommendations for a digest email subscription.
  def for_digest(subscription, limit: 5)
    user = subscription.user
    return cold_start_fallback(limit) unless user

    compute_recommendations_for_user(user, limit)
  end

  private

  def compute_recommendations_for_user(user, limit)
    interactions = gather_user_interactions(user)

    if interactions[:total_count] < COLD_START_THRESHOLD
      return cold_start_fallback(limit)
    end

    topic_scores = compute_topic_scores(interactions)
    interacted_ids = interactions[:content_ids]

    # Get personalized content
    personalized_count = (limit * (1 - DIVERSITY_RATIO)).ceil
    diversity_count = limit - personalized_count

    personalized = personalized_content(topic_scores, interacted_ids, personalized_count)
    diversity = diversity_content(interacted_ids + personalized.map(&:id), diversity_count)

    (personalized + diversity).first(limit)
  end

  def gather_user_interactions(user)
    cutoff_date = LOOKBACK_DAYS.days.ago
    content_ids = Set.new

    # Gather votes (highest signal) - only for ContentItems
    votes = Vote.without_site_scope
               .where(site: @site, user: user, votable_type: "ContentItem")
               .where("created_at >= ?", cutoff_date)
               .order(created_at: :desc)
               .limit(MAX_INTERACTIONS)
               .includes(:votable)

    # Gather bookmarks
    bookmarks = Bookmark.where(user: user, bookmarkable_type: "ContentItem")
                       .where("created_at >= ?", cutoff_date)
                       .order(created_at: :desc)
                       .limit(MAX_INTERACTIONS)
                       .includes(:bookmarkable)

    # Filter bookmarks to only include content items from this site
    bookmarks = bookmarks.select { |b| b.bookmarkable&.site_id == @site.id }

    # Gather views
    views = ContentView.without_site_scope
                      .where(site: @site, user: user)
                      .where("viewed_at >= ?", cutoff_date)
                      .order(viewed_at: :desc)
                      .limit(MAX_INTERACTIONS)
                      .includes(:content_item)

    votes.each { |v| content_ids << v.votable_id }
    bookmarks.each { |b| content_ids << b.bookmarkable_id }
    views.each { |v| content_ids << v.content_item_id }

    {
      votes: votes,
      bookmarks: bookmarks,
      views: views,
      content_ids: content_ids.to_a,
      total_count: votes.size + bookmarks.size + views.size
    }
  end

  def compute_topic_scores(interactions)
    topic_scores = Hash.new(0.0)

    # Process votes
    interactions[:votes].each do |vote|
      weight = apply_time_decay(vote.created_at, VOTE_WEIGHT)
      vote.votable.topic_tags.each do |tag|
        topic_scores[tag] += weight
      end
    end

    # Process bookmarks
    interactions[:bookmarks].each do |bookmark|
      weight = apply_time_decay(bookmark.created_at, BOOKMARK_WEIGHT)
      bookmark.bookmarkable.topic_tags.each do |tag|
        topic_scores[tag] += weight
      end
    end

    # Process views
    interactions[:views].each do |view|
      weight = apply_time_decay(view.viewed_at, VIEW_WEIGHT)
      view.content_item.topic_tags.each do |tag|
        topic_scores[tag] += weight
      end
    end

    # Sort and take top tags
    topic_scores.sort_by { |_tag, score| -score }.first(5).to_h
  end

  def apply_time_decay(timestamp, base_weight)
    days_ago = (Time.current - timestamp) / 1.day
    decay_factor = 1.0 / (1.0 + (days_ago / DECAY_HALF_LIFE_DAYS))
    base_weight * decay_factor
  end

  def personalized_content(topic_scores, exclude_ids, limit)
    return [] if topic_scores.empty?

    top_tags = topic_scores.keys

    ContentItem
      .where(site: @site)
      .published
      .where.not(id: exclude_ids)
      .where("topic_tags ?| array[:tags]", tags: top_tags)
      .order(published_at: :desc)
      .limit(limit)
  end

  def diversity_content(exclude_ids, limit)
    return [] if limit <= 0

    FeedRankingService.ranked_feed(
      site: @site,
      filters: { sort: "top_week" },
      limit: limit * 2
    ).where.not(id: exclude_ids).limit(limit)
  end

  def cold_start_fallback(limit)
    FeedRankingService.ranked_feed(
      site: @site,
      filters: {},
      limit: limit
    )
  end
end
