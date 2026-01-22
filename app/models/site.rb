# frozen_string_literal: true

# == Schema Information
#
# Table name: sites
#
#  id          :bigint           not null, primary key
#  config      :jsonb            not null
#  description :text
#  name        :string           not null
#  slug        :string           not null
#  status      :integer          default("enabled"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_sites_on_status                (status)
#  index_sites_on_tenant_id             (tenant_id)
#  index_sites_on_tenant_id_and_slug    (tenant_id,slug) UNIQUE
#  index_sites_on_tenant_id_and_status  (tenant_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
class Site < ApplicationRecord
  include TenantScoped
  # Associations
  belongs_to :tenant
  has_many :domains, dependent: :destroy
  has_one :primary_domain, -> { where(primary: true) }, class_name: "Domain"
  has_many :sources, dependent: :destroy
  has_many :import_runs, dependent: :destroy
  has_many :content_items, dependent: :destroy

  # Enums
  enum :status, { enabled: 0, disabled: 1, private_access: 2 }

  # Validations
  validates :slug, presence: true, uniqueness: { scope: :tenant_id }, format: {
    with: /\A[a-z0-9_]+\z/,
    message: "must contain only lowercase letters, numbers, and underscores"
  }
  validates :name, presence: true, length: { minimum: 1, maximum: 255 }
  validates :description, length: { maximum: 1000 }, allow_blank: true
  validates :status, presence: true
  validate :validate_config_structure
  validate :ensure_primary_domain_exists, on: :update

  # Callbacks
  after_save :clear_site_cache
  after_destroy :clear_site_cache

  # Scopes
  scope :active, -> { where(status: :enabled) }
  scope :by_tenant, ->(tenant) { where(tenant: tenant) }

  # Class methods
  def self.find_by_hostname!(hostname)
    domain = Domain.find_by!(hostname: hostname)
    domain.site
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordNotFound, "Site not found for hostname: #{hostname}"
  end

  # Instance methods
  def config
    super || {}
  end

  def setting(key, default = nil)
    keys = key.to_s.split(".")
    value = config
    keys.each do |k|
      value = value[k] if value.is_a?(Hash)
    end
    value.nil? ? default : value
  end

  def update_setting(key, value)
    keys = key.to_s.split(".")
    new_config = config.deep_dup

    # Navigate to the nested location
    current = new_config
    keys[0..-2].each do |k|
      current[k] ||= {}
      current = current[k]
    end

    # Set the final value
    current[keys.last] = value

    self.config = new_config
    save!
  end

  # Config helpers for common settings
  def topics
    setting("topics", [])
  end

  def ingestion_sources_enabled?
    setting("ingestion.enabled", true)
  end

  def monetisation_enabled?
    setting("monetisation.enabled", false)
  end

  # Status helpers
  def publicly_accessible?
    enabled?
  end

  def requires_login?
    private_access?
  end

  # Domain helpers
  def primary_hostname
    primary_domain&.hostname
  end

  def verified_domains
    domains.where(verified: true)
  end

  private

  def clear_site_cache
    domains.each do |domain|
      Rails.cache.delete("site:hostname:#{domain.hostname}")
    end
    Rails.cache.delete_matched("site:*")
  end

  def validate_config_structure
    return if config.blank?

    unless config.is_a?(Hash)
      errors.add(:config, "must be a valid JSON object")
      return
    end

    # Validate topics if present
    if config["topics"].present?
      unless config["topics"].is_a?(Array)
        errors.add(:config, "topics must be an array")
      end
    end

    # Validate ingestion settings if present
    if config["ingestion"].present?
      unless config["ingestion"].is_a?(Hash)
        errors.add(:config, "ingestion must be a valid object")
      end
    end

    # Validate monetisation settings if present
    if config["monetisation"].present?
      unless config["monetisation"].is_a?(Hash)
        errors.add(:config, "monetisation must be a valid object")
      end
    end
  end

  def ensure_primary_domain_exists
    return if domains.empty?

    primary_count = domains.where(primary: true).count
    if primary_count == 0
      errors.add(:base, "at least one domain must be marked as primary")
    elsif primary_count > 1
      errors.add(:base, "only one domain can be marked as primary")
    end
  end
end
