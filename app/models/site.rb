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
  include JsonbSettingsAccessor
  self.jsonb_settings_column = :config

  # Associations
  belongs_to :tenant
  has_many :domains, dependent: :destroy
  has_one :primary_domain, -> { where(primary: true) }, class_name: "Domain"
  has_many :sources, dependent: :destroy
  has_many :import_runs, dependent: :destroy
  has_many :entries, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :site_bans, dependent: :destroy
  has_many :flags, dependent: :destroy
  has_many :tagging_rules, dependent: :destroy
  has_many :taxonomies, dependent: :destroy
  has_many :digest_subscriptions, dependent: :destroy
  has_many :boosts_as_source, class_name: "NetworkBoost", foreign_key: :source_site_id, dependent: :destroy, inverse_of: :source_site
  has_many :boosts_as_target, class_name: "NetworkBoost", foreign_key: :target_site_id, dependent: :destroy, inverse_of: :target_site
  has_many :boost_payouts, dependent: :destroy
  has_many :discussions, dependent: :destroy
  has_many :discussion_posts, dependent: :destroy
  has_many :live_streams, dependent: :destroy
  has_many :live_stream_viewers, dependent: :destroy
  has_many :digital_products, dependent: :destroy
  has_many :purchases, dependent: :destroy
  has_many :subscriber_segments, dependent: :destroy
  has_many :subscriber_tags, dependent: :destroy
  has_many :notes, dependent: :destroy

  # Attachments
  has_one_attached :logo

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
  after_create :create_default_subscriber_segments
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

  # Boost settings
  def boosts_enabled?
    setting("boosts.enabled", true)
  end

  def boost_cpc_rate
    setting("boosts.cpc_rate", 0.50)
  end

  def boost_monthly_budget
    setting("boosts.monthly_budget")
  end

  def boosts_display_enabled?
    setting("boosts.display_enabled", true)
  end

  # Moderation settings
  def flag_threshold
    setting("moderation.flag_threshold", 3)
  end

  def flag_notifications_enabled?
    setting("moderation.flag_notifications_enabled", true)
  end

  # Analytics settings
  def ga_measurement_id
    setting("analytics.ga_measurement_id")
  end

  def analytics_enabled?
    ga_measurement_id.present?
  end

  # Scheduling settings
  def scheduling_timezone
    setting("scheduling.timezone", "UTC")
  end

  # Discussion settings
  def discussions_enabled?
    setting("discussions.enabled", false)
  end

  def discussions_default_visibility
    setting("discussions.default_visibility", "public_access")
  end

  # Streaming settings
  def streaming_enabled?
    setting("streaming.enabled", false)
  end

  def streaming_notify_on_live?
    setting("streaming.notify_on_live", true)
  end

  # Digital products settings
  def digital_products_enabled?
    setting("digital_products.enabled", false)
  end

  # Notes settings
  def notes_enabled?
    setting("notes.enabled", true)
  end

  def notes_in_digest?
    setting("digest.include_notes", true)
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

    # Clear only this site's scoped cache entries (multi-tenant safe)
    # Note: delete_matched is not supported by SolidCache, so we skip it in production
    Rails.cache.delete_matched("site:#{id}:*")
  rescue NotImplementedError
    # SolidCache doesn't support delete_matched - individual keys will expire naturally
    Rails.logger.debug { "Cache delete_matched not supported, skipping pattern deletion for site:#{id}" }
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

    # Validate moderation settings if present
    if config["moderation"].present?
      unless config["moderation"].is_a?(Hash)
        errors.add(:config, "moderation must be a valid object")
      end
    end

    # Validate boosts settings if present
    if config["boosts"].present?
      unless config["boosts"].is_a?(Hash)
        errors.add(:config, "boosts must be a valid object")
      end
    end

    # Validate discussions settings if present
    if config["discussions"].present?
      unless config["discussions"].is_a?(Hash)
        errors.add(:config, "discussions must be a valid object")
      end
    end

    # Validate streaming settings if present
    if config["streaming"].present?
      unless config["streaming"].is_a?(Hash)
        errors.add(:config, "streaming must be a valid object")
      end
    end

    # Validate digital_products settings if present
    if config["digital_products"].present?
      unless config["digital_products"].is_a?(Hash)
        errors.add(:config, "digital_products must be a valid object")
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

  def create_default_subscriber_segments
    default_segments = [
      {
        name: "All Subscribers",
        description: "All subscribers regardless of activity or status",
        rules: {},
        system_segment: true
      },
      {
        name: "Active (30 days)",
        description: "Subscribers with engagement activity in the last 30 days",
        rules: { "engagement_level" => { "min_actions" => 1, "within_days" => 30 } },
        system_segment: true
      },
      {
        name: "New (7 days)",
        description: "Subscribers who joined in the last 7 days",
        rules: { "subscription_age" => { "max_days" => 7 } },
        system_segment: true
      },
      {
        name: "Power Users",
        description: "Subscribers with 3 or more confirmed referrals",
        rules: { "referral_count" => { "min" => 3 } },
        system_segment: true
      }
    ]

    default_segments.each do |segment_attrs|
      subscriber_segments.create!(segment_attrs)
    end
  end
end
