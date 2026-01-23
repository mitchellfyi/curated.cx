# frozen_string_literal: true

# Test helpers for tenant context and multi-tenancy
module TenantTestHelpers
  # Set up tenant context for tests
  def setup_tenant_context(tenant)
    # Use for_tenant to bypass ActsAsTenant scoping when Current.tenant is nil
    site = Site.for_tenant(tenant).first || create(:site, tenant: tenant, slug: tenant.slug, name: tenant.title)

    # Ensure there's a domain mapping the tenant's hostname to the site
    # This is required for the TenantResolver middleware to resolve requests
    unless site.domains.exists?(hostname: Domain.normalize_hostname(tenant.hostname))
      create(:domain, site: site, hostname: tenant.hostname, primary: site.domains.empty?)
    end

    Current.site = site
    ActsAsTenant.current_tenant = tenant

    # For controller specs, ensure Current remains set even if reset callbacks run
    if defined?(RSpec) && respond_to?(:allow)
      allow(Current).to receive(:site).and_return(site)
      allow(Current).to receive(:tenant).and_return(tenant)
    end
  end

  # Clear tenant context after tests
  def clear_tenant_context
    Current.tenant = nil
    Current.site = nil
    ActsAsTenant.current_tenant = nil
  end

  # Helper to create a tenant and set it as current
  def with_tenant(tenant_or_attributes = {})
    tenant = if tenant_or_attributes.is_a?(Hash)
               create(:tenant, tenant_or_attributes)
    else
               tenant_or_attributes
    end

    setup_tenant_context(tenant)
    yield(tenant) if block_given?
  ensure
    clear_tenant_context
  end

  # Manual sign in helper for tests when Devise helpers fail
  def manual_sign_in(user)
    # Set the user in the session manually
    session[:user_id] = user.id
    # Also set it in the request for integration tests
    if respond_to?(:request)
      request.session[:user_id] = user.id
    end
  end

  # Helper to set up host-based tenant resolution for tests
  def with_hostname(hostname, tenant = nil)
    tenant ||= create(:tenant, hostname: hostname)

    # Mock the request hostname
    allow_any_instance_of(ActionDispatch::Request).to receive(:host).and_return(hostname)

    setup_tenant_context(tenant)
    yield(tenant) if block_given?
  ensure
    clear_tenant_context
  end
end

# Configure RSpec to include the helpers
RSpec.configure do |config|
  # Include helpers for different test types
  config.include TenantTestHelpers, type: :request
  config.include TenantTestHelpers, type: :controller
  config.include TenantTestHelpers, type: :system
  config.include TenantTestHelpers, type: :model
  config.include TenantTestHelpers, type: :service
  config.include TenantTestHelpers, type: :job

  # Clear tenant context before each test (all types)
  config.before(:each) do
    Current.reset! if Current.respond_to?(:reset!)
    ActsAsTenant.current_tenant = nil
  end

  # Clear tenant context after each test (all types)
  config.after(:each) do
    Current.reset! if Current.respond_to?(:reset!)
    ActsAsTenant.current_tenant = nil
  end
end
