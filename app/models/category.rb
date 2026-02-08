# frozen_string_literal: true

# == Schema Information
#
# Table name: categories
#
#  id           :bigint           not null, primary key
#  allow_paths  :boolean          default(TRUE), not null
#  key          :string           not null
#  name         :string           not null
#  shown_fields :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  site_id      :bigint           not null
#  tenant_id    :bigint           not null
#
# Indexes
#
#  index_categories_on_site_id            (site_id)
#  index_categories_on_site_id_and_key    (site_id,key) UNIQUE
#  index_categories_on_site_id_and_name   (site_id,name)
#  index_categories_on_tenant_id          (tenant_id)
#  index_categories_on_tenant_id_and_key  (tenant_id,key) UNIQUE
#  index_categories_on_tenant_name        (tenant_id,name)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
class Category < ApplicationRecord
  include TenantScoped
  include SiteScoped

  # Category types
  CATEGORY_TYPES = %w[article product service event job media discussion resource].freeze

  # Default display templates per category type
  DISPLAY_TEMPLATES = {
    "article"    => "list",
    "product"    => "grid",
    "service"    => "grid",
    "event"      => "calendar",
    "job"        => "list",
    "media"      => "grid",
    "discussion" => "list",
    "resource"   => "grid"
  }.freeze

  # Icons per category type (emoji)
  CATEGORY_TYPE_ICONS = {
    "article"    => "📰",
    "product"    => "📦",
    "service"    => "🏢",
    "event"      => "📅",
    "job"        => "💼",
    "media"      => "🎬",
    "discussion" => "💬",
    "resource"   => "📚"
  }.freeze

  # Associations
  belongs_to :tenant # Keep for backward compatibility and data access
  has_many :listings, dependent: :destroy

  # Validations
  validates :key, presence: true, uniqueness: { scope: :site_id }
  validates :name, presence: true
  validates :allow_paths, inclusion: { in: [ true, false ] }
  validates :category_type, presence: true, inclusion: { in: CATEGORY_TYPES }
  validate :validate_shown_fields_structure
  validate :validate_metadata_schema_structure

  # Scopes
  scope :allowing_paths, -> { where(allow_paths: true) }
  scope :root_domain_only, -> { where(allow_paths: false) }
  scope :by_type, ->(type) { where(category_type: type) }

  def shown_fields
    super || {}
  end

  def metadata_schema
    super || {}
  end

  # Returns the display template, falling back to type default
  def effective_display_template
    display_template.presence || DISPLAY_TEMPLATES.fetch(category_type, "list")
  end

  # Returns the icon for this category type
  def type_icon
    CATEGORY_TYPE_ICONS.fetch(category_type, "📁")
  end

  # Check if a URL is allowed based on category rules
  def allows_url?(url)
    return true if allow_paths?

    # Root domain only - extract domain and check if it's root-level
    begin
      parsed = URI.parse(url.to_s)
      # Ensure it's a valid HTTP/HTTPS URL with a host
      return false unless parsed.scheme&.match?(/\Ahttps?\z/) && parsed.host.present?

      path = parsed.path || "/"
      path == "/" || path.empty?
    rescue URI::InvalidURIError, ArgumentError
      false
    end
  end

  private

  def validate_shown_fields_structure
    return if shown_fields.blank?

    unless shown_fields.is_a?(Hash)
      errors.add(:shown_fields, "must be a valid JSON object")
    end
  end

  def validate_metadata_schema_structure
    return if metadata_schema.blank?

    unless metadata_schema.is_a?(Hash)
      errors.add(:metadata_schema, "must be a valid JSON object")
    end
  end
end
