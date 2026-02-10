# frozen_string_literal: true

# Service for evaluating subscriber segment rules and returning matching subscriptions.
#
# Rules format (JSONB):
#   {
#     "subscription_age": { "min_days": 7, "max_days": null },
#     "engagement_level": { "min_actions": 5, "within_days": 30 },
#     "referral_count": { "min": 3 },
#     "tags": { "any": ["vip", "beta"], "all": [] },
#     "frequency": "weekly",
#     "active": true
#   }
#
# All rules are combined with AND logic.
class SegmentationService
  class << self
    def subscribers_for(segment)
      new(segment).subscribers
    end
  end

  def initialize(segment)
    @segment = segment
    @rules = segment.rules.with_indifferent_access
  end

  def subscribers
    scope = base_scope

    scope = apply_subscription_age_rule(scope) if @rules[:subscription_age].present?
    scope = apply_engagement_rule(scope) if @rules[:engagement_level].present?
    scope = apply_referral_count_rule(scope) if @rules[:referral_count].present?
    scope = apply_tags_rule(scope) if @rules[:tags].present?
    scope = apply_frequency_rule(scope) if @rules[:frequency].present?
    scope = apply_active_rule(scope) if @rules.key?(:active)

    scope
  end

  private

  def base_scope
    DigestSubscription.without_site_scope.where(site_id: @segment.site_id)
  end

  def apply_subscription_age_rule(scope)
    rule = @rules[:subscription_age]
    min_days = rule[:min_days]
    max_days = rule[:max_days]

    if min_days.present?
      # Subscribed at least N days ago
      scope = scope.where("digest_subscriptions.created_at <= ?", min_days.to_i.days.ago)
    end

    if max_days.present?
      # Subscribed within the last N days
      scope = scope.where("digest_subscriptions.created_at >= ?", max_days.to_i.days.ago)
    end

    scope
  end

  def apply_engagement_rule(scope)
    rule = @rules[:engagement_level]
    min_actions = rule[:min_actions].to_i
    within_days = rule[:within_days]&.to_i || 30

    since_date = within_days.days.ago

    # Build a subquery that counts engagement actions for each user
    # Engagement is votes + bookmarks + content_views within the time window
    engagement_sql = <<~SQL.squish
      (
        SELECT COUNT(*) FROM votes
        WHERE votes.user_id = digest_subscriptions.user_id
          AND votes.site_id = digest_subscriptions.site_id
          AND votes.created_at >= :since_date
      ) + (
        SELECT COUNT(*) FROM bookmarks
        INNER JOIN entries ON bookmarks.bookmarkable_id = entries.id
          AND bookmarks.bookmarkable_type = 'Entry'
        WHERE bookmarks.user_id = digest_subscriptions.user_id
          AND entries.site_id = digest_subscriptions.site_id
          AND bookmarks.created_at >= :since_date
      ) + (
        SELECT COUNT(*) FROM content_views
        WHERE content_views.user_id = digest_subscriptions.user_id
          AND content_views.site_id = digest_subscriptions.site_id
          AND content_views.created_at >= :since_date
      ) >= :min_actions
    SQL

    scope.where(engagement_sql, since_date: since_date, min_actions: min_actions)
  end

  def apply_referral_count_rule(scope)
    rule = @rules[:referral_count]
    min_referrals = rule[:min].to_i

    # Count confirmed + rewarded referrals for each subscription
    referral_sql = <<~SQL.squish
      (
        SELECT COUNT(*) FROM referrals
        WHERE referrals.referrer_subscription_id = digest_subscriptions.id
          AND referrals.status IN (1, 2)
      ) >= :min_referrals
    SQL

    scope.where(referral_sql, min_referrals: min_referrals)
  end

  def apply_tags_rule(scope)
    rule = @rules[:tags]
    any_tags = Array(rule[:any]).reject(&:blank?)
    all_tags = Array(rule[:all]).reject(&:blank?)

    if any_tags.any?
      # Subscription must have at least one of these tags
      scope = scope.where(
        "EXISTS (
          SELECT 1 FROM subscriber_taggings
          INNER JOIN subscriber_tags ON subscriber_tags.id = subscriber_taggings.subscriber_tag_id
          WHERE subscriber_taggings.digest_subscription_id = digest_subscriptions.id
            AND subscriber_tags.slug IN (?)
        )",
        any_tags
      )
    end

    if all_tags.any?
      # Subscription must have ALL of these tags
      all_tags.each do |tag_slug|
        scope = scope.where(
          "EXISTS (
            SELECT 1 FROM subscriber_taggings
            INNER JOIN subscriber_tags ON subscriber_tags.id = subscriber_taggings.subscriber_tag_id
            WHERE subscriber_taggings.digest_subscription_id = digest_subscriptions.id
              AND subscriber_tags.slug = ?
          )",
          tag_slug
        )
      end
    end

    scope
  end

  def apply_frequency_rule(scope)
    frequency = @rules[:frequency]
    scope.where(frequency: frequency)
  end

  def apply_active_rule(scope)
    active = @rules[:active]
    scope.where(active: active)
  end
end
