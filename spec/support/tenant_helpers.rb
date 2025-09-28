# frozen_string_literal: true

# Test helpers for tenant context and multi-tenancy
module TenantTestHelpers
  # Set up tenant context for tests
  def setup_tenant_context(tenant)
    Current.tenant = tenant
    ActsAsTenant.current_tenant = tenant
  end

  # Clear tenant context after tests
  def clear_tenant_context
    Current.tenant = nil
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

  # Set up tenant context for request specs
  config.before(:each, type: :request) do
    # Clear tenant context before each test
    clear_tenant_context
  end

  config.after(:each, type: :request) do
    # Clear tenant context after each test
    clear_tenant_context
  end
end
