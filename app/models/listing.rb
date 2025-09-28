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
#  tenant_id     :bigint           not null
#
# Indexes
#
#  index_listings_on_category_id                (category_id)
#  index_listings_on_domain                     (domain)
#  index_listings_on_published_at               (published_at)
#  index_listings_on_tenant_and_url_canonical   (tenant_id,url_canonical) UNIQUE
#  index_listings_on_tenant_id                  (tenant_id)
#  index_listings_on_tenant_id_and_category_id  (tenant_id,category_id)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
class Listing < ApplicationRecord
  acts_as_tenant :tenant

  # Associations
  belongs_to :tenant
  belongs_to :category

  # Validations
  validates :url_raw, presence: true
  validates :url_canonical, presence: true, uniqueness: { scope: :tenant_id }
  validates :title, presence: true
  validate :validate_url_against_category_rules
  validate :validate_jsonb_fields

  # Callbacks
  before_validation :canonicalize_url, if: :url_raw_changed?
  before_validation :extract_domain_from_canonical, if: :url_canonical_changed?

  # Scopes
  scope :published, -> { where.not(published_at: nil) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }
  scope :by_domain, ->(domain) { where(domain: domain) }
  scope :with_content, -> { where.not(body_html: [nil, '']) }

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
    parts = host.split('.')
    return host if parts.length <= 2

    parts.last(2).join('.')
  rescue URI::InvalidURIError
    nil
  end

  private

  def canonicalize_url
    return unless url_raw.present?

    begin
      # Parse and normalize the URL
      uri = URI.parse(url_raw.strip)
      
      # Validate that it's a proper HTTP/HTTPS URL
      unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        errors.add(:url_raw, "must be a valid HTTP or HTTPS URL")
        return
      end
      
      # Ensure it has a host
      unless uri.host.present?
        errors.add(:url_raw, "must include a valid hostname")
        return
      end
      
      # Normalize scheme
      uri.scheme = uri.scheme.downcase
      
      # Normalize host
      uri.host = uri.host.downcase
      
      # Remove common tracking parameters
      if uri.query
        params = URI.decode_www_form(uri.query)
        # Remove common tracking parameters
        tracking_params = %w[
          utm_source utm_medium utm_campaign utm_term utm_content
          fbclid gclid mc_cid mc_eid
          ref source campaign
        ]
        params = params.reject { |key, _| tracking_params.include?(key.downcase) }
        uri.query = params.empty? ? nil : URI.encode_www_form(params)
      end
      
      # Normalize path (remove trailing slash unless it's root)
      if uri.path && uri.path != '/'
        normalized_path = uri.path.gsub(/\/+$/, '')
        # Only set path if it's valid
        begin
          uri.path = normalized_path unless normalized_path.empty?
        rescue URI::InvalidComponentError
          # Keep original path if normalization fails
        end
      end
      
      self.url_canonical = uri.to_s
    rescue URI::InvalidURIError, ArgumentError => e
      errors.add(:url_raw, "is not a valid URL: #{e.message}")
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
    [ai_summaries, ai_tags, metadata].each_with_index do |field, index|
      field_name = %i[ai_summaries ai_tags metadata][index]
      next if field.blank?

      unless field.is_a?(Hash)
        errors.add(field_name, "must be a valid JSON object")
      end
    end
  end
end
