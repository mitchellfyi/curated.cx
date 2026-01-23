# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id              :bigint           not null, primary key
#  hostname        :string           not null
#  last_checked_at :datetime
#  last_error      :text
#  primary         :boolean          default(FALSE), not null
#  status          :integer          default("pending_dns"), not null
#  verified        :boolean          default(FALSE), not null
#  verified_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  site_id         :bigint           not null
#
# Indexes
#
#  index_domains_on_hostname               (hostname) UNIQUE
#  index_domains_on_site_id                (site_id)
#  index_domains_on_site_id_and_verified   (site_id,verified)
#  index_domains_on_site_id_where_primary  (site_id) UNIQUE WHERE ("primary" = true)
#  index_domains_on_status                 (status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
class Domain < ApplicationRecord
  # Associations
  belongs_to :site

  # Enums
  enum :status, {
    pending_dns: 0,
    verified_dns: 1,
    ssl_pending: 2,
    active: 3,
    failed: 4
  }

  # Validations
  validates :hostname, presence: true, uniqueness: { case_sensitive: true }, format: {
    with: /\A[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]{0,61}[a-z0-9])?)*\z/i,
    message: "must be a valid domain name"
  }
  validates :primary, inclusion: { in: [ true, false ] }
  validates :verified, inclusion: { in: [ true, false ] }
  validates :status, presence: true
  validate :ensure_single_primary_per_site

  # Callbacks
  before_validation :normalize_hostname_before_save
  before_validation :set_initial_status, on: :create
  before_save :set_verified_at
  after_save :clear_domain_cache
  after_destroy :clear_domain_cache

  # Scopes
  scope :primary, -> { where(primary: true) }
  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }
  scope :by_hostname, ->(hostname) { where(hostname: hostname) }
  scope :verification_pending, -> { where(status: [ :pending_dns, :ssl_pending ]) }
  scope :active_or_verified, -> { where(status: [ :active, :verified_dns ]) }

  # Class methods
  # Normalize hostname: lowercase, strip trailing dots, remove port
  def self.normalize_hostname(hostname)
    return nil if hostname.blank?

    # Remove port if present (e.g., "example.com:3000" -> "example.com")
    normalized = hostname.split(":").first

    # Lowercase
    normalized = normalized.downcase

    # Strip trailing dots
    normalized = normalized.sub(/\.+$/, "")

    normalized
  end

  def self.find_by_hostname!(hostname)
    normalized = normalize_hostname(hostname)
    find_by!(hostname: normalized)
  end

  def self.find_by_hostname(hostname)
    normalized = normalize_hostname(hostname)
    find_by(hostname: normalized)
  end

  # Instance methods
  def verify!
    update!(verified: true, verified_at: Time.current)
  end

  def unverify!
    update!(verified: false, verified_at: nil)
  end

  def make_primary!
    Domain.transaction do
      # Unset other primary domains for this site
      site.domains.where.not(id: id).update_all(primary: false)
      # Set this domain as primary
      update!(primary: true)
    end
  end

  # Verification methods
  def check_dns!
    result = dns_verifier.verify

    self.last_checked_at = Time.current

    if result[:verified]
      if status == "pending_dns"
        self.status = :verified_dns
        self.verified = true
        self.verified_at = Time.current
        self.last_error = nil
      end
    else
      if status == "pending_dns" || status == "verified_dns"
        self.status = :failed
        self.last_error = result[:error] || "DNS resolution failed"
      end
    end

    save!
    result
  end

  def dns_verifier
    @dns_verifier ||= DnsVerifier.new(hostname: hostname, expected_target: dns_target)
  end

  # DNS-related methods (shared logic with DnsInstructionsHelper)
  def dns_target
    ENV.fetch("DNS_TARGET", "curated.cx")
  end

  def apex_domain?(hostname = nil)
    hostname ||= self.hostname
    return false if hostname.blank?
    parts = hostname.split(".")
    parts.length == 2 # e.g., "example.com" has 2 parts
  end

  # Status helpers (public - used in views)
  def next_step
    case status
    when "pending_dns"
      "Configure DNS records as shown above, then click 'Check DNS'"
    when "verified_dns"
      "DNS verified. SSL certificate provisioning in progress..."
    when "ssl_pending"
      "Waiting for SSL certificate to be issued..."
    when "active"
      "Domain is active and ready to use"
    when "failed"
      "DNS verification failed. Check your DNS settings and try again."
    end
  end

  def status_color
    case status
    when "pending_dns"
      "yellow"
    when "verified_dns", "ssl_pending"
      "blue"
    when "active"
      "green"
    when "failed"
      "red"
    end
  end

  private

  def normalize_hostname_before_save
    self.hostname = self.class.normalize_hostname(hostname) if hostname.present?
  end

  def set_initial_status
    self.status ||= :pending_dns
  end

  def set_verified_at
    if verified? && verified_at.nil?
      self.verified_at = Time.current
    elsif !verified? && verified_at.present?
      self.verified_at = nil
    end
  end

  def clear_domain_cache
    Rails.cache.delete("site:hostname:#{hostname}")

    # Clear only the associated site's scoped cache entries (multi-tenant safe)
    Rails.cache.delete_matched("site:#{site_id}:*")
  end

  def ensure_single_primary_per_site
    return unless primary?
    return unless site.present?

    existing_primary = site.domains.where(primary: true).where.not(id: id)
    if existing_primary.exists?
      errors.add(:primary, "only one domain can be marked as primary per site")
    end
  end
end
