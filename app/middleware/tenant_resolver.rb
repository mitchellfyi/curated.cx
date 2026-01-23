# frozen_string_literal: true

# Middleware that resolves the current tenant/site from the request hostname.
# Delegates actual resolution to DomainResolver service.
# Does NOT create database records - routing only.
class TenantResolver
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    # Skip site resolution for health check endpoint
    return @app.call(env) if request.path == "/up"

    normalized_host = Domain.normalize_hostname(request.host)
    site = resolve_site(normalized_host)

    if site
      Current.site = site
      @app.call(env)
    else
      redirect_to_domain_not_connected(env, normalized_host || request.host)
    end
  rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid, NoMethodError => e
    Rails.logger.error("TenantResolver error: #{e.class} - #{e.message}")
    Rails.logger.error(e.backtrace.first(5).join("\n"))
    redirect_to_domain_not_connected(env, request.host)
  end

  private

  def resolve_site(hostname)
    return nil if hostname.blank?

    # Handle localhost routing in development/test
    if development_or_test? && localhost?(hostname)
      return resolve_localhost_site(hostname)
    end

    # Standard hostname-based resolution via DomainResolver
    DomainResolver.resolve(hostname)
  end

  def development_or_test?
    Rails.env.development? || Rails.env.test?
  end

  def localhost?(hostname)
    hostname.include?("localhost") || hostname.include?("127.0.0.1") || hostname.include?("0.0.0.0")
  end

  def resolve_localhost_site(hostname)
    # For plain localhost, resolve to root tenant's site
    if %w[localhost 127.0.0.1 0.0.0.0].include?(hostname)
      tenant = Tenant.root_tenant
      return tenant&.sites&.find_by(slug: tenant.slug)
    end

    # For subdomain.localhost, resolve by subdomain slug
    subdomain = hostname.split(".").first
    tenant = Tenant.find_by(slug: subdomain) || Tenant.root_tenant
    tenant&.sites&.find_by(slug: tenant.slug)
  end

  def redirect_to_domain_not_connected(env, hostname)
    env["X_DOMAIN_NOT_CONNECTED"] = hostname
    env["PATH_INFO"] = "/domain_not_connected"
    env["REQUEST_URI"] = "/domain_not_connected"
    env["REQUEST_METHOD"] = "GET"
    @app.call(env)
  end
end
