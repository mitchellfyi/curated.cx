# frozen_string_literal: true

class TenantResolver
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    # Skip site resolution for health check endpoint
    if request.path == "/up"
      return @app.call(env)
    end

    normalized_host = normalize_hostname(request.host)
    site = resolve_site(normalized_host)

    if site
      Current.site = site
      @app.call(env)
    else
      # Redirect to domain not connected page
      redirect_to_domain_not_connected(env, normalized_host || request.host)
    end
  rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid, NoMethodError => e
    # Catch database errors and nil-related errors during site resolution
    Rails.logger.error("TenantResolver error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    redirect_to_domain_not_connected(env, request.host)
  end

  private

  # Normalize hostname: lowercase, strip trailing dots, remove port
  def normalize_hostname(hostname)
    Domain.normalize_hostname(hostname)
  end

  def resolve_site(hostname)
    return nil if hostname.blank?

    # Handle localhost subdomain routing in development and test environments
    if (Rails.env.development? || Rails.env.test?) && localhost?(hostname)
      return resolve_localhost_site(hostname)
    end

    # Standard hostname-based resolution via Domain
    resolve_by_hostname(hostname)
  end

  def localhost?(hostname)
    hostname.include?("localhost") || hostname.include?("127.0.0.1") || hostname.include?("0.0.0.0")
  end

  def resolve_localhost_site(hostname)
    # For plain localhost, resolve to root tenant's site
    if %w[localhost 127.0.0.1 0.0.0.0].include?(hostname)
      tenant = Tenant.root_tenant
      return find_or_create_root_site(tenant)
    end

    # For subdomain.localhost, resolve by subdomain slug
    subdomain = hostname.split(".").first
    tenant = Tenant.find_by(slug: subdomain) || Tenant.root_tenant
    find_or_create_site_for_tenant(tenant)
  end

  def resolve_by_hostname(hostname)
    # Strategy 1: Direct hostname lookup (exact match)
    domain = Domain.find_by_hostname(hostname)
    if domain
      site = domain.site
      return site unless site&.disabled?
    end

    # Strategy 2: www variant lookup (www.example.com -> example.com)
    if hostname.start_with?("www.")
      apex_hostname = hostname.sub(/\Awww\./, "")
      domain = Domain.find_by_hostname(apex_hostname)
      if domain
        site = domain.site
        return site unless site&.disabled?
      end
    end

    # Strategy 3: Apex variant lookup (example.com -> www.example.com)
    unless hostname.start_with?("www.")
      www_hostname = "www.#{hostname}"
      domain = Domain.find_by_hostname(www_hostname)
      if domain
        site = domain.site
        return site unless site&.disabled?
      end
    end

    # Strategy 4: Subdomain pattern (ai.curated.cx -> check if curated.cx has subdomain support)
    # This is optional and can be enabled via Site config later
    if subdomain_pattern_supported?(hostname)
      apex = extract_apex_from_subdomain(hostname)
      if apex
        domain = Domain.find_by_hostname(apex)
        if domain
          site = domain.site
          # Check if site has subdomain pattern enabled
          if site&.setting("domains.subdomain_pattern_enabled", false)
            return site unless site&.disabled?
          end
        end
      end
    end

    # Strategy 5: Fallback to Tenant lookup for backward compatibility
    # This handles existing tenants that haven't been migrated to Site/Domain yet
    begin
      tenant = Tenant.find_by_hostname!(hostname)
      return nil if tenant&.disabled?
      find_or_create_site_for_tenant(tenant)
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  def subdomain_pattern_supported?(hostname)
    # Check if hostname looks like a subdomain pattern (e.g., ai.curated.cx)
    parts = hostname.split(".")
    parts.length >= 3 # subdomain.apex.tld
  end

  def extract_apex_from_subdomain(hostname)
    # Extract apex domain from subdomain (e.g., "ai.curated.cx" -> "curated.cx")
    parts = hostname.split(".")
    return nil if parts.length < 3
    parts[1..-1].join(".")
  end

  def redirect_to_domain_not_connected(env, hostname)
    # Create a new request with the domain_not_connected path
    env["X_DOMAIN_NOT_CONNECTED"] = hostname
    env["PATH_INFO"] = "/domain_not_connected"
    env["REQUEST_URI"] = "/domain_not_connected"
    env["REQUEST_METHOD"] = "GET"

    # Call the app with modified env
    @app.call(env)
  end

  def find_or_create_site_for_tenant(tenant)
    Site.find_by(tenant: tenant, slug: tenant.slug) || create_default_site_for_tenant(tenant)
  end

  def find_or_create_root_site(tenant)
    find_or_create_site_for_tenant(tenant)
  end

  def create_default_site_for_tenant(tenant)
    site = Site.create!(
      tenant: tenant,
      slug: tenant.slug,
      name: tenant.title,
      description: tenant.description,
      status: tenant.status,
      config: tenant.settings
    )

    # Create primary domain from tenant hostname
    site.domains.create!(
      hostname: tenant.hostname,
      primary: true,
      verified: true
    )

    site
  rescue ActiveRecord::RecordInvalid => e
    # If site already exists (race condition), find it
    Site.find_by!(tenant: tenant, slug: tenant.slug)
  end
end
