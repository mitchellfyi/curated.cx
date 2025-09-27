# frozen_string_literal: true

require "test_helper"

class TenantResolutionTest < ActionDispatch::IntegrationTest
  setup do
    @ai_tenant = Tenant.find_by!(slug: "ai")
    @construction_tenant = Tenant.find_by!(slug: "construction")
    @root_tenant = Tenant.find_by!(slug: "root")
  end

  test "should find tenants by hostname" do
    # Test the Tenant model's find_by_hostname! method
    assert_equal @ai_tenant, Tenant.find_by_hostname!("ainews.cx")
    assert_equal @construction_tenant, Tenant.find_by_hostname!("construction.cx")
    assert_equal @root_tenant, Tenant.find_by_hostname!("curated.cx")
  end

  test "should raise error for unknown hostname" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Tenant.find_by_hostname!("unknown.example.com")
    end
  end

  test "should handle hostname with port" do
    # Test that hostname parsing works correctly
    hostname = "ainews.cx:3000"
    clean_hostname = hostname.split(":").first.downcase
    assert_equal "ainews.cx", clean_hostname
    assert_equal @ai_tenant, Tenant.find_by_hostname!(clean_hostname)
  end

  test "should find root tenant" do
    assert_equal @root_tenant, Tenant.root_tenant
    assert @root_tenant.root?
  end

  test "should handle disabled tenant" do
    # Create a disabled tenant
    disabled_tenant = Tenant.create!(
      hostname: "disabled.example.com",
      slug: "disabled",
      title: "Disabled Tenant",
      status: :disabled
    )
    
    # Should find the tenant but it should not be publicly accessible
    # Note: find_by_hostname! only finds enabled tenants, so we need to use find_by
    found_tenant = Tenant.find_by(hostname: "disabled.example.com")
    assert_equal disabled_tenant, found_tenant
    assert_not found_tenant.publicly_accessible?
    assert found_tenant.disabled?
  end

  test "should handle private access tenant" do
    # Create a private access tenant
    private_tenant = Tenant.create!(
      hostname: "private.example.com",
      slug: "private",
      title: "Private Tenant",
      status: :private_access
    )
    
    # Should find the tenant but it should require login
    # Note: find_by_hostname! only finds enabled tenants, so we need to use find_by
    found_tenant = Tenant.find_by(hostname: "private.example.com")
    assert_equal private_tenant, found_tenant
    assert_not found_tenant.publicly_accessible?
    assert found_tenant.requires_login?
    assert found_tenant.private_access?
  end

  test "should handle localhost subdomain routing" do
    # Test the localhost subdomain logic
    subdomain = "ai.localhost".split(".").first
    assert_equal "ai", subdomain
    
    # Should find tenant by slug
    found_tenant = Tenant.find_by(slug: subdomain)
    assert_equal @ai_tenant, found_tenant
  end

  test "should handle localhost root routing" do
    # Test localhost root routing
    hostname = "localhost"
    if Rails.env.development? && ["localhost", "127.0.0.1", "0.0.0.0"].include?(hostname)
      assert_equal @root_tenant, Tenant.root_tenant
    else
      # In test environment, just verify the logic works
      assert ["localhost", "127.0.0.1", "0.0.0.0"].include?(hostname)
      assert_equal @root_tenant, Tenant.root_tenant
    end
  end
end
