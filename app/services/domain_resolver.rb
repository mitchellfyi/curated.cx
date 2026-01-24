# frozen_string_literal: true

# Resolves a hostname to a Site using multiple resolution strategies.
# Does NOT create any database records - read-only resolution only.
#
# Usage:
#   resolver = DomainResolver.new("example.com")
#   site = resolver.resolve  # => Site or nil
#
# Resolution Strategies (in order):
# 1. Exact hostname match via Domain
# 2. WWW variant lookup (www.example.com → example.com)
# 3. Apex variant lookup (example.com → www.example.com)
# 4. Subdomain pattern (ai.curated.cx → curated.cx if enabled)
# 5. Legacy tenant hostname fallback
#
class DomainResolver
  def self.resolve(hostname)
    new(hostname).resolve
  end

  def initialize(hostname)
    @hostname = normalize(hostname)
  end

  attr_reader :hostname

  def resolve
    return nil if hostname.blank?

    resolve_by_exact_match ||
      resolve_by_www_variant ||
      resolve_by_apex_variant ||
      resolve_by_subdomain_pattern ||
      resolve_by_legacy_tenant
  end

  private

  def normalize(hostname)
    Domain.normalize_hostname(hostname)
  end

  def resolve_by_exact_match
    domain = Domain.find_by_hostname(hostname)
    return nil unless domain

    site = domain.site
    return nil if site&.disabled? || site&.tenant&.disabled?
    site
  end

  def resolve_by_www_variant
    return nil unless hostname&.start_with?("www.")

    apex_hostname = hostname.sub(/\Awww\./, "")
    domain = Domain.find_by_hostname(apex_hostname)
    return nil unless domain

    site = domain.site
    return nil if site&.disabled? || site&.tenant&.disabled?
    site
  end

  def resolve_by_apex_variant
    return nil if hostname&.start_with?("www.")

    www_hostname = "www.#{hostname}"
    domain = Domain.find_by_hostname(www_hostname)
    return nil unless domain

    site = domain.site
    return nil if site&.disabled? || site&.tenant&.disabled?
    site
  end

  def resolve_by_subdomain_pattern
    return nil unless subdomain_pattern?(hostname)

    apex = extract_apex(hostname)
    return nil unless apex

    domain = Domain.find_by_hostname(apex)
    return nil unless domain

    site = domain.site
    return nil unless site&.setting("domains.subdomain_pattern_enabled", false)
    return nil if site&.disabled? || site&.tenant&.disabled?
    site
  end

  def resolve_by_legacy_tenant
    tenant = Tenant.find_by_hostname!(hostname)
    return nil if tenant&.disabled?

    tenant.sites.find_by(slug: tenant.slug)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def subdomain_pattern?(hostname)
    return false if hostname.blank?

    hostname.split(".").length >= 3
  end

  def extract_apex(hostname)
    parts = hostname.split(".")
    return nil if parts.length < 3

    parts[1..].join(".")
  end
end
