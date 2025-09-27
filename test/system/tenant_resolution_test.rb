# frozen_string_literal: true

require "application_system_test_case"

class TenantResolutionTest < ApplicationSystemTestCase
  def setup
    @root_tenant = Tenant.find_by!(slug: "root")
    @ainews_tenant = Tenant.find_by!(slug: "ainews")
    @construction_tenant = Tenant.find_by!(slug: "construction")
  end

  test "should resolve root tenant for curated.cx" do
    visit "http://curated.cx:3000"

    # Check that the page shows the correct tenant information
    assert_text @root_tenant.title
    assert_text @root_tenant.slug
  end

  test "should resolve ainews tenant for ainews.cx" do
    visit "http://ainews.cx:3000"

    assert_text @ainews_tenant.title
    assert_text @ainews_tenant.slug
  end

  test "should resolve construction tenant for construction.cx" do
    visit "http://construction.cx:3000"

    assert_text @construction_tenant.title
    assert_text @construction_tenant.slug
  end

  test "should return 404 for unknown hostname" do
    # This test would need to be adapted based on how we handle 404s
    # For now, we'll test that the middleware properly sets the tenant context
    visit "http://unknown.example.com:3000"

    # Should show 404 page
    assert_text "Tenant not found"
  end
end
