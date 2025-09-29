# frozen_string_literal: true

class TenantResolver
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    # Skip tenant resolution for health check endpoint
    if request.path == "/up"
      return @app.call(env)
    end

    tenant = resolve_tenant(request.host)

    if tenant
      Current.tenant = tenant
      @app.call(env)
    else
      [ 404, { "Content-Type" => "text/html" }, [ "Tenant not found" ] ]
    end
  rescue => e
    # Only catch tenant resolution errors, not application errors
    if e.message.include?("TenantResolver") || e.is_a?(ActiveRecord::RecordNotFound)
      Rails.logger.error("TenantResolver error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      [ 404, { "Content-Type" => "text/html" }, [ "Tenant not found" ] ]
    else
      # Re-raise application errors
      raise
    end
  end

  private

  def resolve_tenant(hostname)
    return nil if hostname.blank?

    # Remove port if present (e.g., "localhost:3000" -> "localhost")
    clean_hostname = hostname.split(":").first.downcase

    # Handle localhost subdomain routing in development
    if Rails.env.development? && localhost?(clean_hostname)
      return resolve_localhost_tenant(clean_hostname)
    end

    # Standard hostname-based resolution
    resolve_by_hostname(clean_hostname)
  end

  def localhost?(hostname)
    hostname.include?("localhost") || hostname.include?("127.0.0.1") || hostname.include?("0.0.0.0")
  end

  def resolve_localhost_tenant(hostname)
    # For plain localhost, resolve to root tenant
    if %w[localhost 127.0.0.1 0.0.0.0].include?(hostname)
      return Tenant.root_tenant
    end

    # For subdomain.localhost, resolve by subdomain slug
    subdomain = hostname.split(".").first
    Tenant.find_by(slug: subdomain) || Tenant.root_tenant
  end

  def resolve_by_hostname(hostname)
    tenant = Tenant.find_by_hostname!(hostname)

    # Only allow enabled and private_access tenants
    tenant unless tenant&.disabled?
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
