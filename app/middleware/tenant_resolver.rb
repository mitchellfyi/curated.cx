# frozen_string_literal: true

class TenantResolver
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    hostname = request.host

    # Set the current tenant based on hostname
    tenant = resolve_tenant(hostname)

    if tenant
      Current.tenant = tenant
      @app.call(env)
    else
      # Return 404 for unknown hostnames
      [ 404, { "Content-Type" => "text/html" }, [ "Tenant not found" ] ]
    end
  rescue => e
    Rails.logger.error "TenantResolver error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Fallback to root tenant on error
    Current.tenant = Tenant.root_tenant
    @app.call(env)
  end

  private

  def resolve_tenant(hostname)
    # Remove port if present (e.g., "localhost:3000" -> "localhost")
    clean_hostname = hostname.to_s.split(":").first.downcase

    # In development, handle localhost subdomains
    if Rails.env.development? && clean_hostname.include?("localhost")
      return handle_localhost_routing(clean_hostname)
    end

    # Try to find tenant by hostname first
    tenant = find_tenant_by_domain(clean_hostname)

    # Ensure tenant is publicly accessible
    return nil unless tenant&.publicly_accessible?

    tenant
  rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid => e
    Rails.logger.warn "TenantResolver: Failed to find tenant for hostname '#{hostname}': #{e.message}"
    nil
  end

  def find_tenant_by_domain(hostname)
    Tenant.find_by_hostname!(hostname)
  end

  def handle_localhost_routing(hostname)
    if Rails.env.development? && [ "localhost", "127.0.0.1", "0.0.0.0" ].include?(hostname)
      return Tenant.root_tenant
    end

    # Extract subdomain and use as slug
    subdomain = hostname.split(".").first
    Tenant.find_by(slug: subdomain) || Tenant.root_tenant
  rescue ActiveRecord::RecordNotFound
    Tenant.root_tenant
  end
end
