# frozen_string_literal: true

# Current context for storing request-scoped data
# Scoping boundary: Site is the primary isolation boundary.
# Tenant is derived from Site for backward compatibility.
class Current < ActiveSupport::CurrentAttributes
  attribute :site

  # Tenant is derived from site for backward compatibility
  def self.tenant
    site&.tenant
  end

  # Backward-compatible setter to allow setting Current.tenant in legacy code/tests
  def self.tenant=(value)
    case value
    when Site
      self.site = value
    when Tenant
      site_for_tenant = value.sites.first || Site.create!(
        tenant: value,
        slug: value.slug,
        name: value.title,
        description: value.description,
        config: value.settings,
        status: value.status
      )
      self.site = site_for_tenant
    when nil
      self.site = nil
    else
      raise ArgumentError, "Unsupported tenant assignment"
    end
  end

  # Set both site and ensure tenant is accessible
  def self.site=(value)
    super(value)
  end

  # Reset the current site (and tenant) (useful for testing)
  def self.reset!
    reset
  end

  # Legacy method for backward compatibility
  def self.reset_tenant!
    reset
  end

  # Ensure we always have a site set
  def self.ensure_site!
    raise "No site set in Current context" if site.nil?
  end

  # Legacy method for backward compatibility
  def self.ensure_tenant!
    ensure_site!
  end
end
