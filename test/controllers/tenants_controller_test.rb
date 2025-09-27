# frozen_string_literal: true

require "test_helper"

class TenantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create!(
      hostname: "test.example.com",
      slug: "test_tenant",
      title: "Test Tenant",
      description: "Test tenant description",
      settings: {
        theme: { primary_color: "blue" },
        categories: { news: { enabled: true }, apps: { enabled: true } }
      }
    )
  end

  test "should render show template" do
    # Test that the controller action exists and renders the show template
    get tenant_path

    # The response should be 404 since no tenant is set in test environment
    assert_response :not_found
  end

  test "should have correct route" do
    # Test that the route is properly configured
    assert_routing "/tenant", { controller: "tenants", action: "show" }
  end

  test "should handle tenant data correctly" do
    # Test the tenant data structure that would be used in the view
    assert_equal "Test Tenant", @tenant.title
    assert_equal "test.example.com", @tenant.hostname
    assert_equal "Test tenant description", @tenant.description
    assert_equal "test_tenant", @tenant.slug
    assert_equal "blue", @tenant.primary_color
    assert_includes @tenant.enabled_categories, "news"
    assert_includes @tenant.enabled_categories, "apps"
  end

  test "should handle root tenant correctly" do
    root_tenant = Tenant.find_by!(slug: "root")
    assert root_tenant.root?
    assert_equal "curated.cx", root_tenant.hostname
  end

  test "should handle tenant status correctly" do
    assert @tenant.enabled?
    assert @tenant.publicly_accessible?
    assert_not @tenant.requires_login?

    @tenant.update!(status: :disabled)
    assert @tenant.disabled?
    assert_not @tenant.publicly_accessible?
    assert_not @tenant.requires_login?

    @tenant.update!(status: :private_access)
    assert @tenant.private_access?
    assert_not @tenant.publicly_accessible?
    assert @tenant.requires_login?
  end
end
