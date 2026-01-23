# frozen_string_literal: true

# == Schema Information
#
# Table name: content_items
#
#  id             :bigint           not null, primary key
#  description    :text
#  extracted_text :text
#  published_at   :datetime
#  raw_payload    :jsonb            not null
#  summary        :text
#  tags           :jsonb            not null
#  title          :string
#  url_canonical  :string           not null
#  url_raw        :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#  source_id      :bigint           not null
#
# Indexes
#
#  index_content_items_on_published_at               (published_at)
#  index_content_items_on_site_id                    (site_id)
#  index_content_items_on_site_id_and_url_canonical  (site_id,url_canonical) UNIQUE
#  index_content_items_on_source_id                  (source_id)
#  index_content_items_on_source_id_and_created_at   (source_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#
class ContentItem < ApplicationRecord
  include SiteScoped

  # Associations
  belongs_to :source

  # Validations
  validates :url_canonical, presence: true, uniqueness: { scope: :site_id }
  validates :url_raw, presence: true
  validates :raw_payload, presence: true
  validates :tags, presence: true

  # Callbacks
  before_validation :normalize_url_canonical
  before_validation :ensure_tags_is_array

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_source, ->(source) { where(source: source) }
  scope :published, -> { where.not(published_at: nil) }
  scope :unpublished, -> { where(published_at: nil) }

  # Class methods
  # Find or initialize by canonical URL (for deduplication)
  def self.find_or_initialize_by_canonical_url(site:, url_canonical:, source:)
    find_or_initialize_by(site: site, url_canonical: url_canonical) do |item|
      item.source = source
      item.url_raw = url_canonical # Default to canonical if raw not provided
    end
  end

  # Instance methods
  def raw_payload
    super || {}
  end

  def tags
    super || []
  end

  def published?
    published_at.present?
  end

  private

  def normalize_url_canonical
    return unless url_canonical.present?
    # Use UrlCanonicaliser to normalize the canonical URL
    # This ensures consistent format even if caller passes already-canonicalized URL
    normalized = UrlCanonicaliser.canonicalize(url_canonical)
    self.url_canonical = normalized
  rescue UrlCanonicaliser::InvalidUrlError => e
    errors.add(:url_canonical, e.message)
  rescue StandardError => e
    # If canonicalization fails, log but don't fail validation (raw URL is stored)
    Rails.logger.warn("URL canonicalization failed for #{url_canonical}: #{e.message}")
  end

  def ensure_tags_is_array
    self.tags = [] unless tags.is_a?(Array)
  end
end
