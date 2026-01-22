# frozen_string_literal: true

# == Schema Information
#
# Table name: listings
#
#  id            :bigint           not null, primary key
#  ai_summaries  :jsonb            not null
#  ai_tags       :jsonb            not null
#  body_html     :text
#  body_text     :text
#  description   :text
#  domain        :string
#  image_url     :text
#  metadata      :jsonb            not null
#  published_at  :datetime
#  site_name     :string
#  title         :string
#  url_canonical :text             not null
#  url_raw       :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  category_id   :bigint           not null
#  site_id       :bigint           not null
#  source_id     :bigint
#  tenant_id     :bigint           not null
#
# Indexes
#
#  index_listings_on_category_id                (category_id)
#  index_listings_on_category_published         (category_id,published_at)
#  index_listings_on_domain                     (domain)
#  index_listings_on_published_at               (published_at)
#  index_listings_on_site_id                    (site_id)
#  index_listings_on_site_id_and_url_canonical  (site_id,url_canonical) UNIQUE
#  index_listings_on_source_id                  (source_id)
#  index_listings_on_tenant_and_url_canonical   (tenant_id,url_canonical) UNIQUE
#  index_listings_on_tenant_domain_published    (tenant_id,domain,published_at)
#  index_listings_on_tenant_id                  (tenant_id)
#  index_listings_on_tenant_id_and_category_id  (tenant_id,category_id)
#  index_listings_on_tenant_id_and_source_id    (tenant_id,source_id)
#  index_listings_on_tenant_published_created   (tenant_id,published_at,created_at)
#  index_listings_on_tenant_title               (tenant_id,title)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
class Listing < ApplicationRecord
  include TenantScoped
  include SiteScoped

  # Associations
  belongs_to :tenant # Keep for backward compatibility and data access
  belongs_to :category
  belongs_to :source, optional: true

  # Validations
  validates :category, presence: true
  validates :url_raw, presence: true
  validates :url_canonical, presence: true, uniqueness: { scope: :site_id }
  validates :title, presence: true
  validate :validate_url_against_category_rules
  validate :validate_jsonb_fields
  validate :ensure_site_tenant_consistency

  # Callbacks
  before_validation :set_tenant_from_site, on: :create
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
  end

  def set_tenant_from_site
    self.tenant = site.tenant if site.present? && tenant.nil?
  end

  def ensure_site_tenant_consistency
    if site.present? && tenant.present? && site.tenant != tenant
      errors.add(:site, "must belong to the same tenant")
    end
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
    [ ai_summaries, ai_tags, metadata ].each_with_index do |field, index|
      field_name = %i[ai_summaries ai_tags metadata][index]
      next if field.blank?

      unless field.is_a?(Hash)
        errors.add(field_name, "must be a valid JSON object")
      end
    end
  end
end
