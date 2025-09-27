# frozen_string_literal: true

# == Schema Information
#
# Table name: tenants
#
#  id          :bigint           not null, primary key
#  description :text
#  hostname    :string           not null
#  logo_url    :string
#  settings    :jsonb            not null
#  slug        :string           not null
#  status      :integer          default("enabled"), not null
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_tenants_on_hostname  (hostname) UNIQUE
#  index_tenants_on_slug      (slug) UNIQUE
#  index_tenants_on_status    (status)
#
class Tenant < ApplicationRecord
  # Enums
  enum :status, { enabled: 0, disabled: 1, private_access: 2 }

  # Validations
  validates :hostname, presence: true, uniqueness: true, format: {
    with: /\A[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?)*\z/i,
    message: "must be a valid domain name"
  }
  validates :slug, presence: true, uniqueness: true, format: {
    with: /\A[a-z0-9_]+\z/,
    message: "must contain only lowercase letters, numbers, and underscores"
  }
  validates :title, presence: true, length: { minimum: 1, maximum: 255 }
  validates :description, length: { maximum: 1000 }, allow_blank: true
  validates :logo_url, format: {
    with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    message: "must be a valid URL"
  }, allow_blank: true
  validates :status, presence: true
  validate :validate_settings_structure

  # Callbacks
  after_save :clear_tenant_cache
  after_destroy :clear_tenant_cache

  # Scopes
  scope :active, -> { where(status: :enabled) }
  scope :by_hostname, ->(hostname) { where(hostname: hostname) }

  # Class methods
  def self.find_by_hostname!(hostname)
    Rails.cache.fetch("tenant:hostname:#{hostname}", expires_in: 1.hour) do
      find_by!(hostname: hostname, status: :enabled)
    end
  end


  def self.root_tenant
    Rails.cache.fetch("tenant:root", expires_in: 1.hour) do
      find_by!(slug: "root")
    end
  end

  def self.clear_cache!
    Rails.cache.delete_matched("tenant:*")
  end

  # Instance methods
  def root?
    slug == "root"
  end

  def settings
    super || {}
  end

  def setting(key, default = nil)
    keys = key.to_s.split(".")
    value = settings
    keys.each do |k|
      value = value[k] if value.is_a?(Hash)
    end
    value || default
  end

  def update_setting(key, value)
    keys = key.to_s.split(".")
    new_settings = settings.deep_dup

    # Navigate to the nested location
    current = new_settings
    keys[0..-2].each do |k|
      current[k] ||= {}
      current = current[k]
    end

    # Set the final value
    current[keys.last] = value

    self.settings = new_settings
    save!
  end

  # Category helpers
  def category_enabled?(category_name)
    setting("categories.#{category_name}.enabled", false)
  end

  def enabled_categories
    categories = setting("categories", {})
    categories.select { |_, config| config["enabled"] }.keys
  end

  # Theme helpers
  def primary_color
    setting("theme.primary_color", "blue")
  end

  def secondary_color
    setting("theme.secondary_color", "gray")
  end

  # Status helpers
  def publicly_accessible?
    enabled?
  end

  def requires_login?
    private_access?
  end

  private

  def clear_tenant_cache
    Rails.cache.delete("tenant:hostname:#{hostname}")
    Rails.cache.delete("tenant:root") if root?

    # Also clear any cached instances that might be stale
    Rails.cache.delete_matched("tenant:*")
  end

  def validate_settings_structure
    return if settings.blank?

    unless settings.is_a?(Hash)
      errors.add(:settings, "must be a valid JSON object")
      return
    end

    # Validate theme settings
    if settings["theme"].present?
      theme = settings["theme"]
      unless theme.is_a?(Hash)
        errors.add(:settings, "theme must be a valid object")
        return
      end

      valid_colors = %w[blue gray red yellow green indigo purple pink amber]
      if theme["primary_color"].present? && !valid_colors.include?(theme["primary_color"])
        errors.add(:settings, "primary_color must be a valid Tailwind color")
      end
      if theme["secondary_color"].present? && !valid_colors.include?(theme["secondary_color"])
        errors.add(:settings, "secondary_color must be a valid Tailwind color")
      end
    end

    # Validate categories settings
    if settings["categories"].present?
      categories = settings["categories"]
      unless categories.is_a?(Hash)
        errors.add(:settings, "categories must be a valid object")
        return
      end

      categories.each do |category_name, config|
        unless config.is_a?(Hash) && config.key?("enabled")
          errors.add(:settings, "category '#{category_name}' must have an 'enabled' property")
        end
      end
    end
  end
end
