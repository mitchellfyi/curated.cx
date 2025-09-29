# frozen_string_literal: true

module TenantScoped
  extend ActiveSupport::Concern

  included do
    # Use acts_as_tenant for automatic tenant scoping
    acts_as_tenant :tenant

    # Validate tenant presence
    belongs_to :tenant
    validates :tenant, presence: true

    # Add tenant_id to all queries by default, but only if Current.tenant is set
    # This ensures that unscoped queries (e.g., in console or background jobs)
    # don't fail if Current.tenant is not explicitly set.
    default_scope { where(tenant: Current.tenant) if Current.tenant }

    # Class methods
    def self.without_tenant_scope
      unscoped
    end

    def self.for_tenant(tenant)
      unscoped.where(tenant: tenant)
    end

    def self.require_tenant!
      raise "Current.tenant must be set to perform this operation" unless Current.tenant
    end
  end

  class_methods do
    # Override acts_as_tenant's default behavior to use Current.tenant
    def acts_as_tenant_tenant
      Current.tenant
    end
  end

  # Instance methods
  def ensure_tenant_consistency!
    if Current.tenant && tenant != Current.tenant
      raise "Record belongs to different tenant than Current.tenant"
    end
  end

  # Common JSONB field accessors with fallback to empty hash
  def jsonb_field(field_name)
    read_attribute(field_name) || {}
  end
end
