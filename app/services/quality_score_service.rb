# frozen_string_literal: true

# Computes a quality score for content items based on available metadata.
# This provides a fallback scoring mechanism when AI-generated quality scores
# are not available (e.g., for items processed with v1.0.0 prompts).
#
# Usage:
#   score = QualityScoreService.score(entry)
#   # => 6.5
#
#   QualityScoreService.score!(entry) # updates the record
#
class QualityScoreService
  # Maximum possible score
  MAX_SCORE = 10.0

  # Weights for each scoring dimension
  WEIGHTS = {
    content_depth: 3.0,
    freshness: 2.0,
    engagement: 2.5,
    completeness: 2.5
  }.freeze

  def self.score(entry)
    new(entry).calculate
  end

  def self.score!(entry)
    score = new(entry).calculate
    entry.update_column(:quality_score, score)
    score
  end

  def initialize(entry)
    @entry = entry
  end

  def calculate
    total_weight = WEIGHTS.values.sum
    raw = (
      content_depth_score * WEIGHTS[:content_depth] +
      freshness_score * WEIGHTS[:freshness] +
      engagement_score * WEIGHTS[:engagement] +
      completeness_score * WEIGHTS[:completeness]
    ) / total_weight

    raw.clamp(0.0, MAX_SCORE).round(1)
  end

  private

  attr_reader :entry

  # Score based on word count / text length (0-10)
  def content_depth_score
    word_count = entry.word_count || estimate_word_count
    return 0.0 if word_count.zero?

    # 300+ words = full score, scales linearly below
    [ word_count / 300.0 * MAX_SCORE, MAX_SCORE ].min
  end

  # Score based on how recent the content is (0-10)
  def freshness_score
    published = entry.published_at
    return 5.0 unless published # neutral score if unknown

    days_old = (Time.current - published).to_f / 1.day
    return MAX_SCORE if days_old <= 1
    return 8.0 if days_old <= 7
    return 6.0 if days_old <= 30
    return 4.0 if days_old <= 90

    2.0
  end

  # Score based on community engagement (0-10)
  def engagement_score
    upvotes = entry.upvotes_count.to_i
    comments = entry.comments_count.to_i
    total = upvotes + comments * 2 # comments weighted more

    return 0.0 if total.zero?

    # 20+ engagement points = full score
    [ total / 20.0 * MAX_SCORE, MAX_SCORE ].min
  end

  # Score based on metadata completeness (0-10)
  def completeness_score
    fields = 0
    fields += 1 if entry.title.present?
    fields += 1 if entry.description.present?
    fields += 1 if entry.ai_summary.present?
    fields += 1 if entry.why_it_matters.present?
    fields += 1 if entry.extracted_text.present?
    fields += 1 if entry.og_image_url.present?
    fields += 1 if entry.author_name.present?
    fields += 1 if entry.read_time_minutes.present?
    fields += 1 if entry.key_takeaways&.any?
    fields += 1 if entry.topic_tags.any?

    (fields / 10.0 * MAX_SCORE).round(1)
  end

  def estimate_word_count
    text = entry.extracted_text
    return 0 if text.blank?

    text.split(/\s+/).size
  end
end
