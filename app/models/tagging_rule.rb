# frozen_string_literal: true

class TaggingRule < ApplicationRecord
  include TenantScoped
  include SiteScoped

  # Associations
  belongs_to :tenant
  belongs_to :taxonomy

  # Enums
  enum :rule_type, { url_pattern: 0, source: 1, keyword: 2, domain: 3 }

  # Validations
  validates :pattern, presence: true
  validates :priority, presence: true, numericality: { only_integer: true }
  validates :rule_type, presence: true
  validates :enabled, inclusion: { in: [ true, false ] }

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :by_priority, -> { order(priority: :asc) }
  scope :for_type, ->(type) { where(rule_type: type) }

  # Instance method: evaluate rule against a content item
  # Returns: { match: bool, confidence: float, reason: string }
  def matches?(content_item)
    return no_match unless enabled?

    case rule_type
    when "url_pattern"
      evaluate_url_pattern(content_item)
    when "source"
      evaluate_source(content_item)
    when "keyword"
      evaluate_keyword(content_item)
    when "domain"
      evaluate_domain(content_item)
    else
      no_match
    end
  end

  private

  def no_match
    { match: false, confidence: 0.0, reason: nil }
  end

  def evaluate_url_pattern(content_item)
    return no_match if content_item.url_canonical.blank?

    regex = Regexp.new(pattern, Regexp::IGNORECASE)
    if regex.match?(content_item.url_canonical)
      { match: true, confidence: 1.0, reason: "URL matched pattern '#{pattern}'" }
    else
      no_match
    end
  rescue RegexpError
    no_match
  end

  def evaluate_source(content_item)
    return no_match if content_item.source_id.blank?

    source_id = pattern.to_i
    if content_item.source_id == source_id
      { match: true, confidence: 0.9, reason: "Content from source ##{source_id}" }
    else
      no_match
    end
  end

  def evaluate_keyword(content_item)
    text = [
      content_item.title,
      content_item.extracted_text,
      content_item.description
    ].compact.join(" ")
    return no_match if text.blank?

    keywords = pattern.split(",").map(&:strip).reject(&:blank?)
    return no_match if keywords.empty?

    match_count = keywords.count do |keyword|
      text.downcase.include?(keyword.downcase)
    end

    if match_count.positive?
      confidence = [ 0.7 + (0.1 * match_count), 0.9 ].min
      matched = keywords.select { |k| text.downcase.include?(k.downcase) }
      { match: true, confidence: confidence, reason: "Keywords matched: #{matched.join(', ')}" }
    else
      no_match
    end
  end

  def evaluate_domain(content_item)
    return no_match if content_item.url_canonical.blank?

    begin
      uri = URI.parse(content_item.url_canonical)
      host = uri.host&.downcase
      return no_match if host.blank?

      pattern_regex = Regexp.new(pattern.gsub("*", ".*"), Regexp::IGNORECASE)
      if pattern_regex.match?(host)
        { match: true, confidence: 0.85, reason: "Domain '#{host}' matched pattern '#{pattern}'" }
      else
        no_match
      end
    rescue URI::InvalidURIError, RegexpError
      no_match
    end
  end
end
