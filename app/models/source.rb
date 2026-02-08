# frozen_string_literal: true

# == Schema Information
#
# Table name: sources
#
#  id                       :bigint           not null, primary key
#  config                   :jsonb            not null
#  editorialisation_enabled :boolean          default(FALSE), not null
#  enabled                  :boolean          default(TRUE), not null
#  kind                     :integer          not null
#  last_run_at              :datetime
#  last_status              :string
#  name                     :string           not null
#  quality_weight           :decimal(3, 2)    default(1.0), not null
#  schedule                 :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  site_id                  :bigint           not null
#  tenant_id                :bigint           not null
#
# Indexes
#
#  index_sources_on_site_id                (site_id)
#  index_sources_on_site_id_and_name       (site_id,name) UNIQUE
#  index_sources_on_tenant_id              (tenant_id)
#  index_sources_on_tenant_id_and_enabled  (tenant_id,enabled)
#  index_sources_on_tenant_id_and_kind     (tenant_id,kind)
#  index_sources_on_tenant_id_and_name     (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
class Source < ApplicationRecord
  include TenantScoped
  include SiteScoped

  # Associations
  belongs_to :tenant # Keep for backward compatibility
  has_many :listings, dependent: :nullify
  has_many :import_runs, dependent: :destroy
  has_many :content_items, dependent: :destroy

  # Enums
  enum :kind, {
    serp_api_google_news: 0,
    rss: 1,
    api: 2,
    web_scraper: 3,
    serp_api_google_jobs: 4,
    serp_api_youtube: 5,
    hacker_news: 6
  }

  # Validations
  validates :name, presence: true, uniqueness: { scope: :site_id }
  validates :kind, presence: true
  validates :enabled, inclusion: { in: [ true, false ] }
  validates :quality_weight,
            numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 2.0 },
            allow_nil: true
  validate :validate_config_structure
  validate :validate_schedule_structure

  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }
  scope :by_kind, ->(kind) { where(kind: kind) }
  scope :due_for_run, -> {
    where(enabled: true)
      .where("last_run_at IS NULL OR last_run_at < ?", 1.hour.ago)
  }

  # Class methods
  def self.for_site(site)
    where(site: site)
  end

  # Legacy method for backward compatibility
  def self.for_tenant(tenant)
    joins(:site).where(sites: { tenant: tenant })
  end

  # Instance methods
  def config
    super || {}
  end

  def schedule
    super || {}
  end

  def run_due?
    return true if last_run_at.nil?
    return false unless enabled?

    interval = schedule_interval_seconds
    return false if interval.nil?

    last_run_at < interval.seconds.ago
  end

  def schedule_interval_seconds
    schedule["interval_seconds"] || schedule[:interval_seconds]
  end

  def update_run_status(status)
    update_columns(
      last_run_at: Time.current,
      last_status: status.to_s
    )
  end

  # Check if AI editorialisation is enabled for this source
  def editorialisation_enabled?
    config["editorialise"] == true || config[:editorialise] == true
  end

  # Calculate when this source will next be processed
  def next_run_at
    return nil unless enabled?

    interval = schedule_interval_seconds
    return nil if interval.nil?
    return Time.current if last_run_at.nil?

    last_run_at + interval.seconds
  end

  # Health status based on recent import runs
  # :healthy = last run succeeded, :warning = intermittent failures, :failing = consecutive failures, :unknown = never run
  def health_status
    return :unknown if last_run_at.nil?

    recent = import_runs.order(started_at: :desc).limit(3).pluck(:status)
    return :unknown if recent.empty?

    if recent.first == "completed"
      :healthy
    elsif recent.all? { |s| s == "failed" }
      :failing
    else
      :warning
    end
  end

  # Human-readable description of what this source kind does
  def kind_description
    {
      "serp_api_google_news" => "Searches Google News via SerpAPI",
      "rss" => "Fetches and parses RSS/Atom feeds",
      "api" => "Fetches data from a custom API endpoint",
      "web_scraper" => "Scrapes content from web pages",
      "serp_api_google_jobs" => "Searches Google Jobs via SerpAPI",
      "serp_api_youtube" => "Searches YouTube via SerpAPI",
      "hacker_news" => "Fetches stories from Hacker News via Algolia API"
    }[kind] || "Unknown source type"
  end

  # Human-readable schedule interval
  def schedule_interval_text
    interval = schedule_interval_seconds
    return "Not scheduled" if interval.nil?

    case interval
    when 0..899 then "Every #{(interval / 60.0).ceil} minutes"
    when 900 then "Every 15 minutes"
    when 1800 then "Every 30 minutes"
    when 3600 then "Hourly"
    when 7200..10800 then "Every #{interval / 3600} hours"
    when 21600 then "Every 6 hours"
    when 43200 then "Every 12 hours"
    when 86400 then "Daily"
    when 604800 then "Weekly"
    else "Every #{(interval / 3600.0).round(1)} hours"
    end
  end

  private

  def validate_config_structure
    return if config.blank?

    unless config.is_a?(Hash)
      errors.add(:config, "must be a valid JSON object")
    end
  end

  def validate_schedule_structure
    return if schedule.blank?

    unless schedule.is_a?(Hash)
      errors.add(:schedule, "must be a valid JSON object")
    end
  end
end
