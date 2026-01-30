# frozen_string_literal: true

# == Schema Information
#
# Table name: listings
#
#  id                         :bigint           not null, primary key
#  affiliate_attribution      :jsonb            not null
#  affiliate_url_template     :text
#  ai_summaries               :jsonb            not null
#  ai_tags                    :jsonb            not null
#  apply_url                  :text
#  body_html                  :text
#  body_text                  :text
#  company                    :string
#  description                :text
#  domain                     :string
#  expires_at                 :datetime
#  featured_from              :datetime
#  featured_until             :datetime
#  image_url                  :text
#  listing_type               :integer          default("tool"), not null
#  location                   :string
#  metadata                   :jsonb            not null
#  paid                       :boolean          default(FALSE), not null
#  payment_reference          :string
#  payment_status             :integer          default("unpaid"), not null
#  published_at               :datetime
#  salary_range               :string
#  site_name                  :string
#  title                      :string
#  url_canonical              :text             not null
#  url_raw                    :text             not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  category_id                :bigint           not null
#  featured_by_id             :bigint
#  site_id                    :bigint           not null
#  source_id                  :bigint
#  stripe_checkout_session_id :string
#  stripe_payment_intent_id   :string
#  tenant_id                  :bigint           not null
#
# Indexes
#
#  index_listings_on_category_id                 (category_id)
#  index_listings_on_category_published          (category_id,published_at)
#  index_listings_on_domain                      (domain)
#  index_listings_on_featured_by_id              (featured_by_id)
#  index_listings_on_payment_status              (payment_status)
#  index_listings_on_published_at                (published_at)
#  index_listings_on_site_expires_at             (site_id,expires_at)
#  index_listings_on_site_featured_dates         (site_id,featured_from,featured_until)
#  index_listings_on_site_id                     (site_id)
#  index_listings_on_site_id_and_url_canonical   (site_id,url_canonical) UNIQUE
#  index_listings_on_site_listing_type           (site_id,listing_type)
#  index_listings_on_site_type_expires           (site_id,listing_type,expires_at)
#  index_listings_on_source_id                   (source_id)
#  index_listings_on_stripe_checkout_session_id  (stripe_checkout_session_id) UNIQUE WHERE (stripe_checkout_session_id IS NOT NULL)
#  index_listings_on_stripe_payment_intent_id    (stripe_payment_intent_id) UNIQUE WHERE (stripe_payment_intent_id IS NOT NULL)
#  index_listings_on_tenant_and_url_canonical    (tenant_id,url_canonical) UNIQUE
#  index_listings_on_tenant_domain_published     (tenant_id,domain,published_at)
#  index_listings_on_tenant_id                   (tenant_id)
#  index_listings_on_tenant_id_and_category_id   (tenant_id,category_id)
#  index_listings_on_tenant_id_and_source_id     (tenant_id,source_id)
#  index_listings_on_tenant_published_created    (tenant_id,published_at,created_at)
#  index_listings_on_tenant_title                (tenant_id,title)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (featured_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
class Listing < ApplicationRecord
  include TenantScoped
  include SiteScoped
  include PgSearch::Model

  # Full-text search
  pg_search_scope :search_content,
    against: {
      title: "A",
      description: "B",
      company: "C",
      body_text: "D"
    },
    using: {
      tsearch: { prefix: true, dictionary: "english" }
    }

  # Enums
  enum :listing_type, { tool: 0, job: 1, service: 2 }, default: :tool
  enum :payment_status, {
    unpaid: 0,
    pending_payment: 1,
    paid: 2,
    payment_failed: 3,
    refunded: 4
  }, default: :unpaid, prefix: :payment

  # Associations
  belongs_to :tenant # Keep for backward compatibility and data access
  belongs_to :category
  belongs_to :source, optional: true
  belongs_to :featured_by, class_name: "User", optional: true
  has_many :affiliate_clicks, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy

  # Validations
  validates :category, presence: true
  validates :url_raw, presence: true
  validates :url_canonical, presence: true, uniqueness: { scope: :site_id }
  validates :title, presence: true
  validate :validate_url_against_category_rules
  validate :validate_jsonb_fields

  # Callbacks
  before_validation :canonicalize_url, if: :url_raw_changed?
  before_validation :extract_domain_from_canonical, if: :url_canonical_changed?
  after_save :clear_listing_cache
  after_destroy :clear_listing_cache

  # Scopes
  scope :published, -> { where.not(published_at: nil) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }
  scope :by_domain, ->(domain) { where(domain: domain) }
  scope :with_content, -> { where.not(body_html: [ nil, "" ]) }
  scope :by_tenant_and_category, ->(tenant_id, category_id) {
    where(tenant_id: tenant_id, category_id: category_id)
  }
  scope :published_recent, -> { published.recent }
  scope :by_source, ->(source) { where(source: source) }
  scope :without_source, -> { where(source_id: nil) }

  # Monetisation scopes
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
  scope :jobs, -> { where(listing_type: :job) }
  scope :tools, -> { where(listing_type: :tool) }
  scope :services, -> { where(listing_type: :service) }
  scope :active_jobs, -> { jobs.not_expired.published }
  scope :with_affiliate, -> { where.not(affiliate_url_template: [ nil, "" ]) }
  scope :paid_listings, -> { where(paid: true) }

  # Class methods for common queries
  def self.recent_published_for_site(site_id, limit: 20)
    Rails.cache.fetch("listings:recent:#{site_id}:#{limit}", expires_in: 5.minutes) do
      includes(:category, :site)
        .where(site_id: site_id)
        .published_recent
        .limit(limit)
        .to_a
    end
  end

  def self.count_by_category_for_site(site_id)
    Rails.cache.fetch("listings:count_by_category:#{site_id}", expires_in: 10.minutes) do
      where(site_id: site_id)
        .joins(:category)
        .group("categories.name")
        .count
    end
  end

  # Legacy method for backward compatibility
  def self.recent_published_for_tenant(tenant_id, limit: 20)
    recent_published_for_site(
      Site.where(tenant_id: tenant_id).pluck(:id).first || tenant_id,
      limit: limit
    )
  end

  def self.count_by_category_for_tenant(tenant_id)
    count_by_category_for_site(
      Site.where(tenant_id: tenant_id).pluck(:id).first || tenant_id
    )
  end

  # Published status
  def published?
    published_at.present?
  end

  def ai_summaries
    super || {}
  end

  def ai_tags
    super || {}
  end

  def metadata
    super || {}
  end

  def affiliate_attribution
    super || {}
  end

  # Monetisation status methods

  # Returns true if listing is currently featured
  def featured?
    return false if featured_from.blank?

    now = Time.current
    featured_from <= now && (featured_until.nil? || featured_until > now)
  end

  # Returns true if listing has expired (past expires_at)
  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  # Returns true if listing has affiliate tracking configured
  def has_affiliate?
    affiliate_url_template.present?
  end

  # Returns the affiliate URL or canonical URL for display
  def display_url
    affiliate_url.presence || url_canonical
  end

  # Returns the affiliate URL with tracking params applied
  def affiliate_url
    return nil unless has_affiliate?

    AffiliateUrlService.new(self).generate_url
  end

  # Get root domain from canonical URL
  def root_domain
    return nil unless url_canonical.present?

    uri = URI.parse(url_canonical)
    host = uri.host
    return nil unless host

    # Simple root domain extraction (could be enhanced with public_suffix gem)
    parts = host.split(".")
    return host if parts.length <= 2

    parts.last(2).join(".")
  rescue URI::InvalidURIError
    nil
  end

  private

  def clear_listing_cache
    # Clear specific cache keys more efficiently (use site_id for isolation)
    Rails.cache.delete_matched("listings:recent:#{site_id}:*")
    Rails.cache.delete_matched("listings:count_by_category:#{site_id}:*")
  rescue NotImplementedError
    # SolidCache doesn't support delete_matched - individual keys will expire naturally
    Rails.logger.debug { "Cache delete_matched not supported, skipping pattern deletion for listing:#{id}" }
  end

  def canonicalize_url
    return unless url_raw.present?

    begin
      self.url_canonical = UrlCanonicaliser.canonicalize(url_raw)
    rescue UrlCanonicaliser::InvalidUrlError => e
      errors.add(:url_raw, e.message)
    end
  end

  def extract_domain_from_canonical
    return unless url_canonical.present?

    uri = URI.parse(url_canonical)
    self.domain = uri.host&.downcase if uri.host
  rescue URI::InvalidURIError
    self.domain = nil
  end

  def validate_url_against_category_rules
    return unless category && url_canonical.present?

    unless category.allows_url?(url_canonical)
      errors.add(:url_canonical, "must be a root domain URL for this category")
    end
  end

  def validate_jsonb_fields
    [ ai_summaries, ai_tags, metadata, affiliate_attribution ].each_with_index do |field, index|
      field_name = %i[ai_summaries ai_tags metadata affiliate_attribution][index]
      next if field.blank?

      unless field.is_a?(Hash)
        errors.add(field_name, "must be a valid JSON object")
      end
    end
  end
end
