# frozen_string_literal: true

# Unified model for feed (auto-ingested) and directory (curated) content.
# Discriminator: entry_kind (feed | directory).
#
# == Schema Information
#
# Table name: entries
#
# (See schema.rb or run annotate for full schema.)
#
class Entry < ApplicationRecord
  include SiteScoped
  include PgSearch::Model

  # Kind discriminator
  ENTRY_KINDS = %w[feed directory].freeze
  enum :entry_kind, { feed: "feed", directory: "directory" }, default: :feed

  # Payment status (directory / paid listings)
  enum :payment_status, {
    unpaid: 0,
    pending_payment: 1,
    paid: 2,
    payment_failed: 3,
    refunded: 4
  }, default: :unpaid, prefix: :payment

  # Enrichment status (feed)
  ENRICHMENT_STATUSES = %w[pending enriching complete failed].freeze

  delegate :name, :primary_domain, :primary_hostname, to: :site, prefix: true, allow_nil: true
  delegate :name, to: :source, prefix: true, allow_nil: true
  delegate :name, to: :category, prefix: true, allow_nil: true

  # Full-text search
  pg_search_scope :search_content,
    against: {
      title: "A",
      description: "B",
      ai_summary: "C",
      company: "D",
      body_text: "E"
    },
    using: {
      tsearch: { prefix: true, dictionary: "english" }
    }

  # Associations
  belongs_to :source, optional: true
  belongs_to :tenant, optional: true
  belongs_to :category, optional: true
  belongs_to :hidden_by, class_name: "User", optional: true
  belongs_to :comments_locked_by, class_name: "User", optional: true
  belongs_to :featured_by, class_name: "User", optional: true

  has_many :votes, as: :votable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :flags, as: :flaggable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :content_views, dependent: :destroy
  has_one :editorialisation, dependent: :destroy
  has_many :affiliate_clicks, dependent: :destroy

  # Validations
  validates :url_canonical, presence: true, uniqueness: { scope: [ :site_id, :entry_kind ] }
  validates :url_raw, presence: true
  validates :raw_payload, presence: true, if: :feed?
  validates :tags, presence: true, if: :feed?
  validates :enrichment_status, inclusion: { in: ENRICHMENT_STATUSES }, if: :feed?
  validates :category, presence: true, if: :directory?
  validates :title, presence: true, if: :directory?

  validate :validate_url_against_category_rules, if: -> { directory? && category && url_canonical.present? }
  validate :validate_jsonb_fields, if: :directory?

  # Callbacks
  before_validation :normalize_url_canonical
  before_validation :ensure_tags_is_array, if: :feed?
  before_validation :canonicalize_url, if: -> { directory? && url_raw_changed? }
  before_validation :extract_domain_from_canonical, if: -> { directory? && url_canonical_changed? }

  after_create :apply_tagging_rules, if: :feed?
  after_create :enqueue_enrichment_pipeline, if: :feed?
  after_save :clear_entry_cache, if: :directory?
  after_destroy :clear_entry_cache, if: :directory?

  # Kind scopes
  scope :feed_items, -> { where(entry_kind: "feed") }
  scope :directory_items, -> { where(entry_kind: "directory") }

  # Common scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_source, ->(source) { where(source: source) }
  scope :published, -> { where.not(published_at: nil) }
  scope :unpublished, -> { where(published_at: nil) }
  scope :by_content_type, ->(type) { where(content_type: type) }
  scope :tagged_with, ->(taxonomy_slug) { where("topic_tags @> ?", [ taxonomy_slug ].to_json) }

  # Scheduling
  scope :scheduled, -> { where("scheduled_for > ?", Time.current) }
  scope :not_scheduled, -> { where(scheduled_for: nil) }
  scope :due_for_publishing, -> { where("scheduled_for IS NOT NULL AND scheduled_for <= ?", Time.current) }

  # Feed scopes
  scope :not_hidden, -> { where(hidden_at: nil) }
  scope :for_feed, -> { feed_items.published.not_hidden.not_scheduled.order(published_at: :desc) }
  scope :for_directory, -> { directory_items.published }
  scope :published_since, ->(time) { published.where("published_at >= ?", time) }
  scope :top_this_week, -> { published_since(1.week.ago).order(Arel.sql("(upvotes_count + comments_count) DESC, published_at DESC")) }
  scope :by_engagement, -> { order(Arel.sql("(upvotes_count + comments_count) DESC")) }
  scope :by_quality_score, ->(min_score) { where("quality_score >= ?", min_score) }

  # Enrichment (feed)
  scope :enrichment_pending, -> { where(enrichment_status: "pending") }
  scope :enrichment_complete, -> { where(enrichment_status: "complete") }
  scope :enrichment_failed, -> { where(enrichment_status: "failed") }
  scope :enrichment_stale, ->(interval = 30.days) { enrichment_complete.where("enriched_at < ?", interval.ago) }

  # Directory scopes
  scope :by_domain, ->(domain) { where(domain: domain) }
  scope :with_content, -> { where.not(body_html: [ nil, "" ]) }
  scope :featured, -> {
    where("featured_from <= ? AND (featured_until IS NULL OR featured_until > ?)",
          Time.current, Time.current)
  }
  scope :not_featured, -> {
    where("featured_from IS NULL OR featured_from > ? OR " \
          "(featured_until IS NOT NULL AND featured_until <= ?)",
          Time.current, Time.current)
  }
  scope :not_expired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at IS NOT NULL AND expires_at <= ?", Time.current) }
  scope :in_category, ->(cat) { where(category_id: cat) }
  scope :with_affiliate, -> { where.not(affiliate_url_template: [ nil, "" ]) }
  scope :paid_listings, -> { where(paid: true) }

  scope :from_today, -> { where("published_at >= ?", Time.current.beginning_of_day) }
  scope :from_this_week, -> { where("published_at >= ?", 1.week.ago.beginning_of_day) }
  scope :from_this_month, -> { where("published_at >= ?", 1.month.ago.beginning_of_day) }

  scope :filtered, ->(params) {
    scope = all
    scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
    scope = scope.search_content(params[:q]) if params[:q].present?
    case params[:freshness]
    when "today" then scope = scope.from_today
    when "week" then scope = scope.from_this_week
    when "month" then scope = scope.from_this_month
    end
    scope
  }

  # Class methods
  def self.find_or_initialize_by_canonical_url(site:, url_canonical:, source:, entry_kind: "feed")
    find_or_initialize_by(site: site, url_canonical: url_canonical, entry_kind: entry_kind) do |entry|
      entry.source = source if source
      entry.url_raw = url_canonical
    end
  end

  def self.recent_published_for_site(site_id, limit: 20, kind: "directory")
    Rails.cache.fetch("entries:recent:#{site_id}:#{kind}:#{limit}", expires_in: 5.minutes) do
      includes(:category, :site)
        .where(site_id: site_id, entry_kind: kind)
        .published
        .recent
        .limit(limit)
        .to_a
    end
  end

  def self.count_by_category_for_site(site_id)
    Rails.cache.fetch("entries:count_by_category:#{site_id}", expires_in: 10.minutes) do
      directory_items
        .where(site_id: site_id)
        .joins(:category)
        .group("categories.name")
        .count
    end
  end

  # Raw payload / tags (feed)
  def raw_payload
    super || {}
  end

  def tags
    super || []
  end

  def published?
    published_at.present?
  end

  def scheduled?
    scheduled_for.present? && scheduled_for > Time.current
  end

  def topic_tags
    super || []
  end

  def topic_tags_string=(value)
    self.topic_tags = value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def topic_tags_string
    topic_tags.join(", ")
  end

  def tagging_explanation
    super || []
  end

  def ai_suggested_tags
    super || []
  end

  def key_takeaways
    super || []
  end

  def audience_tags
    super || []
  end

  def metadata
    super || {}
  end

  def affiliate_attribution
    super || {}
  end

  def editorialised?
    editorialised_at.present?
  end

  # Enrichment (feed)
  def enrichment_pending?
    enrichment_status == "pending"
  end

  def enrichment_complete?
    enrichment_status == "complete"
  end

  def enrichment_failed?
    enrichment_status == "failed"
  end

  def enriched?
    enriched_at.present?
  end

  def mark_enrichment_started!
    update_columns(enrichment_status: "enriching", enrichment_errors: [])
  end

  def mark_enrichment_complete!
    update_columns(enrichment_status: "complete", enriched_at: Time.current)
  end

  def mark_enrichment_failed!(error_message)
    errors_list = (enrichment_errors || []) + [ { error: error_message, at: Time.current.iso8601 } ]
    update_columns(enrichment_status: "failed", enrichment_errors: errors_list.to_json)
  end

  def reset_enrichment!
    update_columns(enrichment_status: "pending", enriched_at: nil, enrichment_errors: [].to_json)
  end

  def screenshot_captured?
    screenshot_captured_at.present?
  end

  def screenshot_stale?(interval = 7.days)
    screenshot_captured_at.present? && screenshot_captured_at < interval.ago
  end

  def preview_image_url
    screenshot_url.presence || og_image_url.presence || image_url.presence
  end

  # Moderation
  def hidden?
    hidden_at.present?
  end

  def comments_locked?
    comments_locked_at.present?
  end

  def hide!(user)
    update!(hidden_at: Time.current, hidden_by: user)
  end

  def unhide!
    update!(hidden_at: nil, hidden_by: nil)
  end

  def lock_comments!(user)
    update!(comments_locked_at: Time.current, comments_locked_by: user)
  end

  def unlock_comments!
    update!(comments_locked_at: nil, comments_locked_by: nil)
  end

  # Directory / monetisation
  LISTING_TYPE_KEYS = %w[tool job service].freeze

  def job?
    directory? && listing_type.to_i == 1
  end

  def listing_type_key
    LISTING_TYPE_KEYS[listing_type.to_i] || "tool"
  end

  def views_count
    content_views.count
  end

  def featured?
    return false if featured_from.blank?
    now = Time.current
    featured_from <= now && (featured_until.nil? || featured_until > now)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def has_affiliate?
    affiliate_url_template.present?
  end

  def display_url
    affiliate_url.presence || url_canonical
  end

  def affiliate_url
    return nil unless has_affiliate?
    AffiliateUrlService.new(self).generate_url
  end

  def root_domain
    return nil unless url_canonical.present?
    uri = URI.parse(url_canonical)
    host = uri.host
    return nil unless host
    parts = host.split(".")
    return host if parts.length <= 2
    parts.last(2).join(".")
  rescue URI::InvalidURIError
    nil
  end

  private

  def apply_tagging_rules
    result = TaggingService.tag(self)
    update_columns(
      topic_tags: result[:topic_tags],
      content_type: result[:content_type],
      tagging_confidence: result[:confidence],
      tagging_explanation: result[:explanation]
    )
  end

  def normalize_url_canonical
    return unless url_canonical.present?
    normalized = UrlCanonicaliser.canonicalize(url_canonical)
    self.url_canonical = normalized
  rescue UrlCanonicaliser::InvalidUrlError => e
    errors.add(:url_canonical, e.message)
  rescue StandardError => e
    Rails.logger.warn("URL canonicalization failed for #{url_canonical}: #{e.message}")
  end

  def ensure_tags_is_array
    self.tags = [] unless tags.is_a?(Array)
  end

  def enqueue_enrichment_pipeline
    EnrichEntryJob.perform_later(id)
  end

  def canonicalize_url
    return unless url_raw.present?
    self.url_canonical = UrlCanonicaliser.canonicalize(url_raw)
  rescue UrlCanonicaliser::InvalidUrlError => e
    errors.add(:url_raw, e.message)
  end

  def extract_domain_from_canonical
    return unless url_canonical.present?
    uri = URI.parse(url_canonical)
    self.domain = uri.host&.downcase if uri.host
  rescue URI::InvalidURIError
    self.domain = nil
  end

  def clear_entry_cache
    Rails.cache.delete_matched("entries:recent:#{site_id}:*")
    Rails.cache.delete_matched("entries:count_by_category:#{site_id}:*")
  rescue NotImplementedError
    Rails.logger.debug { "Cache delete_matched not supported for entry:#{id}" }
  end

  def validate_url_against_category_rules
    return unless category && url_canonical.present?
    unless category.allows_url?(url_canonical)
      errors.add(:url_canonical, "must be a root domain URL for this category")
    end
  end

  def validate_jsonb_fields
    %i[metadata affiliate_attribution].each do |field_name|
      val = public_send(field_name)
      next if val.blank?
      errors.add(field_name, "must be a valid JSON object") unless val.is_a?(Hash)
    end
  end
end
