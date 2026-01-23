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

  # Associations
  belongs_to :tenant # Keep for backward compatibility and data access
  has_many :listings, dependent: :destroy

  # Validations
  validates :key, presence: true, uniqueness: { scope: :site_id }

  validates :name, presence: true
  validates :allow_paths, inclusion: { in: [ true, false ] }
  validate :validate_shown_fields_structure

  # Scopes
  scope :allowing_paths, -> { where(allow_paths: true) }
  scope :root_domain_only, -> { where(allow_paths: false) }

  def shown_fields
    super || {}
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
end
