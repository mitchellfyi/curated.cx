# frozen_string_literal: true

class TenantResolver
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      puts "TenantResolver: Starting middleware"
      request = ActionDispatch::Request.new(env)
      hostname = request.host
      puts "TenantResolver: Processing request for hostname: #{hostname}"

      # Skip tenant resolution for health check endpoint
      if request.path == "/up"
        puts "TenantResolver: Skipping tenant resolution for health check endpoint"
        return @app.call(env)
      end

      # Set the current tenant based on hostname
      tenant = resolve_tenant(hostname)
      puts "TenantResolver: Resolved tenant: #{tenant&.title || 'nil'}"

      if tenant
        Current.tenant = tenant
        puts "TenantResolver: Set Current.tenant to: #{Current.tenant.title}"
        @app.call(env)
      else
        puts "TenantResolver: No tenant found for hostname: #{hostname}"
        # Return 404 for unknown hostnames or disabled tenants
        [ 404, { "Content-Type" => "text/html" }, [ "Tenant not found" ] ]
      end
    rescue => e
      puts "TenantResolver error: #{e.message}"
      puts "TenantResolver error class: #{e.class}"
      puts e.backtrace.join("\n")

      # Fallback to root tenant on error
      Current.tenant = Tenant.find_by(slug: "root")
      puts "TenantResolver: Fallback to root tenant due to error"
      @app.call(env)
    end
  end

  private

  def resolve_tenant(hostname)
    # Remove port if present (e.g., "localhost:3000" -> "localhost")
    clean_hostname = hostname.to_s.split(":").first.downcase
    Rails.logger.info "TenantResolver: resolve_tenant called with: #{hostname}, clean_hostname: #{clean_hostname}"

    # In test environment, handle all hostnames by looking them up in the database
    if Rails.env.test?
      Rails.logger.info "TenantResolver: Test environment detected"
      return handle_test_environment(clean_hostname)
    end

    # In development, handle localhost subdomains
    if Rails.env.development? && clean_hostname.include?("localhost")
      Rails.logger.info "TenantResolver: Development environment with localhost detected"
      return handle_localhost_routing(clean_hostname)
    end

    Rails.logger.debug "TenantResolver: Attempting to find tenant by hostname: #{clean_hostname}"
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
    Rails.logger.debug "TenantResolver: Test environment, hostname: #{hostname}"

    # In test environment, handle localhost subdomains for system tests
    if hostname.include?("localhost")
      result = handle_localhost_routing(hostname)
      Rails.logger.debug "TenantResolver: Localhost routing result: #{result&.title || 'nil'}"
      return result
    end

    # For other hostnames in test, look up tenant by hostname directly
    # This allows system tests to use any hostname as long as the tenant exists in the test database
    result = Tenant.find_by(hostname: hostname)
    Rails.logger.debug "TenantResolver: Direct lookup result: #{result&.title || 'nil'}"

    # Ensure tenant is not disabled (allow enabled and private_access)
    return nil if result&.disabled?

    result
  rescue ActiveRecord::RecordNotFound
    Rails.logger.debug "TenantResolver: RecordNotFound for hostname: #{hostname}"
    nil
  end

  def handle_localhost_routing(hostname)
    Rails.logger.debug "TenantResolver: handle_localhost_routing called with: #{hostname}"

    if Rails.env.development? && [ "localhost", "127.0.0.1", "0.0.0.0" ].include?(hostname)
      Rails.logger.debug "TenantResolver: Plain localhost detected, returning root tenant"
      return Tenant.root_tenant
    end

    # Extract subdomain and use as slug
    subdomain = hostname.split(".").first
    Rails.logger.debug "TenantResolver: Extracted subdomain: #{subdomain} from hostname: #{hostname}"

    tenant = Tenant.find_by(slug: subdomain)
    Rails.logger.debug "TenantResolver: Found tenant by slug '#{subdomain}': #{tenant&.title || 'nil'}"

    result = tenant || Tenant.root_tenant
    Rails.logger.debug "TenantResolver: Returning tenant: #{result.title}"
    result
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.debug "TenantResolver: RecordNotFound for slug '#{subdomain}', falling back to root tenant"
    Tenant.root_tenant
  end
end
