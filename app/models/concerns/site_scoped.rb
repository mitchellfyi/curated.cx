# frozen_string_literal: true

# SiteScoped concern ensures all records are scoped to the current site.
# This is the primary isolation boundary - each domain is its own micro-network.
# Content, votes, comments, and listings never leak across Sites.
#
# Also provides tenant/site consistency validation - ensures that a record's
# tenant matches its site's tenant. This prevents data isolation violations.
module SiteScoped
  extend ActiveSupport::Concern

  included do
    # Validate site presence
    belongs_to :site
    validates :site, presence: true

    # Add site_id to all queries by default, but only if Current.site is set
    # This ensures that unscoped queries (e.g., in console or background jobs)
    # don't fail if Current.site is not explicitly set.
    default_scope { where(site: Current.site) if Current.site }

    # Tenant/site consistency callbacks and validations
    # The callback sets tenant from site on create (when tenant is nil)
    # The validation ensures consistency as a safety net for edge cases
    # (console operations, data migrations, API imports with explicit tenant)
    before_validation :set_tenant_from_site, on: :create
    validate :ensure_site_tenant_consistency

    # Class methods
    def self.without_site_scope
      unscoped
    end

    def self.for_site(site)
      unscoped.where(site: site)
    end

    def self.require_site!
      raise "Current.site must be set to perform this operation" unless Current.site
    end
  end

  # Instance methods
  def ensure_site_consistency!
    if Current.site && site != Current.site
      raise "Record belongs to different site than Current.site"
    end
  end

  private

  # Sets tenant from site on create when tenant is not already set.
  # This allows models to be created with just a site, and the tenant
  # will be inferred automatically.
  def set_tenant_from_site
    self.tenant = site.tenant if site.present? && tenant.nil?
  end

  # Validates that the record's tenant matches its site's tenant.
  # This is a safety net that catches edge cases like:
  # - Data migrations that set tenant directly
  # - Console operations with incorrect setup
  # - Seeds/fixtures with mismatched data
  # - API imports with explicit tenant setting
  def ensure_site_tenant_consistency
    if site.present? && tenant.present? && site.tenant_id != tenant_id
      errors.add(:site, "must belong to the same tenant")
    end
  end
end
