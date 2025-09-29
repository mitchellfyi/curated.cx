# frozen_string_literal: true

class TenantResolver
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    hostname = request.host

    # Skip tenant resolution for health check endpoint
    if request.path == "/up"
      return @app.call(env)
    end

    # Set the current tenant based on hostname
    tenant = resolve_tenant(hostname)

    if tenant
      Current.tenant = tenant
      @app.call(env)
    else
      # Return 404 for unknown hostnames or disabled tenants
      [ 404, { "Content-Type" => "text/html" }, [ "Tenant not found" ] ]
    end
  rescue => e
    Rails.logger.error("TenantResolver error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Fallback to root tenant on error
    Current.tenant = Tenant.find_by(slug: "root")
    @app.call(env)
  end

  private

  def resolve_tenant(hostname)
    # Remove port if present (e.g., "localhost:3000" -> "localhost")
    clean_hostname = hostname.to_s.split(":").first.downcase

    # In test environment, handle all hostnames by looking them up in the database
    if Rails.env.test?
      return handle_test_environment(clean_hostname)
    end

    # In development, handle localhost subdomains
    if Rails.env.development? && clean_hostname.include?("localhost")
      return handle_localhost_routing(clean_hostname)
    end

    # Try to find tenant by hostname first
    tenant = find_tenant_by_domain(clean_hostname)

    # Ensure tenant is not disabled (allow enabled and private_access)
    return nil if tenant&.disabled?

    tenant
  rescue ActiveRecord::RecordNotFound, ActiveRecord::StatementInvalid => e
    Rails.logger.warn "TenantResolver: Failed to find tenant for hostname '#{hostname}': #{e.message}"
    nil
  end

  def find_tenant_by_domain(hostname)
    Tenant.find_by!(hostname: hostname)
  end

  def handle_test_environment(hostname)
    # In test environment, handle localhost subdomains for system tests
    if hostname.include?("localhost")
      result = handle_localhost_routing(hostname)
      return result
    end

    # For other hostnames in test, look up tenant by hostname directly
    # This allows system tests to use any hostname as long as the tenant exists in the test database
    result = Tenant.find_by(hostname: hostname)

    # Ensure tenant is not disabled (allow enabled and private_access)
    return nil if result&.disabled?

    result
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def handle_localhost_routing(hostname)
    if Rails.env.development? && [ "localhost", "127.0.0.1", "0.0.0.0" ].include?(hostname)
      return Tenant.root_tenant
    end

    # Extract subdomain and use as slug
    subdomain = hostname.split(".").first

    tenant = Tenant.find_by(slug: subdomain)

    result = tenant || Tenant.root_tenant
    result
  rescue ActiveRecord::RecordNotFound => e
    Tenant.root_tenant
  end
end
