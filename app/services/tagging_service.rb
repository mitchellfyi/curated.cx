# frozen_string_literal: true

# Service to apply tagging rules to content items.
# Evaluates rules in priority order and assigns topic tags, content type, and confidence.
#
# Usage:
#   result = TaggingService.tag(content_item)
#   # => { topic_tags: ["tech", "news"], content_type: "article", confidence: 0.9, explanation: [...] }
#
class TaggingService
  def self.tag(content_item)
    new(content_item).call
  end

  def initialize(content_item)
    @content_item = content_item
  end

  def call
    return empty_result if @content_item.blank? || @content_item.site_id.blank?

    rules = fetch_rules
    return empty_result if rules.empty?

    matched_rules = evaluate_rules(rules)
    build_result(matched_rules)
  end

  private

  def empty_result
    { topic_tags: [], content_type: nil, confidence: nil, explanation: [] }
  end

  def fetch_rules
    TaggingRule.without_site_scope
               .where(site_id: @content_item.site_id, enabled: true)
               .includes(:taxonomy)
               .by_priority
  end

  def evaluate_rules(rules)
    rules.filter_map do |rule|
      result = rule.matches?(@content_item)
      if result[:match]
        {
          rule: rule,
          taxonomy: rule.taxonomy,
          confidence: result[:confidence],
          reason: result[:reason]
        }
      end
    end
  end

  def build_result(matched_rules)
    return empty_result if matched_rules.empty?

    topic_tags = matched_rules.map { |m| m[:taxonomy].slug }.uniq
    max_confidence = matched_rules.map { |m| m[:confidence] }.max
    explanation = matched_rules.map do |m|
      { rule_id: m[:rule].id, taxonomy_slug: m[:taxonomy].slug, reason: m[:reason] }
    end

    # Content type (format: article, tutorial, opinion, etc.) is set by AI
    # editorialisation, not by tagging rules. Rules only assign topic tags.
    {
      topic_tags: topic_tags,
      content_type: nil,
      confidence: max_confidence,
      explanation: explanation
    }
  end
end
