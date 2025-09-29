# frozen_string_literal: true

require "test_helper"

class TenantResolverTest < ActiveSupport::TestCase
  def setup
    @app = ->(env) { [ 200, {}, [ "OK" ] ] }
    @middleware = TenantResolver.new(@app)

    # Ensure tenants exist (they should be seeded)
    @root_tenant = Tenant.find_by!(slug: "root")
    @ai_tenant = Tenant.find_by!(slug: "ai")
  end

  test "should resolve tenant by hostname" do
    env = { "HTTP_HOST" => "ainews.cx" }
    Current.reset_tenant!

    status, _, _ = @middleware.call(env)

    assert_equal 200, status
    assert_equal @ai_tenant, Current.tenant
  end

  test "should resolve root tenant by hostname" do
    env = { "HTTP_HOST" => "curated.cx" }
    Current.reset_tenant!

    status, _, _ = @middleware.call(env)

    assert_equal 200, status
    assert_equal @root_tenant, Current.tenant
  end

  test "should handle hostname with port" do
    env = { "HTTP_HOST" => "ainews.cx:3000" }
    Current.reset_tenant!

    status, _, _ = @middleware.call(env)

    assert_equal 200, status
    assert_equal @ai_tenant, Current.tenant
  end

  test "should return 404 for unknown hostname" do
    env = { "HTTP_HOST" => "unknown.example.com" }
    Current.reset_tenant!

    status, _, body = @middleware.call(env)

    assert_equal 404, status
    assert_equal "Tenant not found", body.first
    assert_nil Current.tenant
  end

  test "should return 404 for inactive tenant" do
    Tenant.create!(
      hostname: "inactive.example.com",
      slug: "inactive",
      title: "Inactive Tenant",
      status: "disabled"
    )

    env = { "HTTP_HOST" => "inactive.example.com" }
    Current.reset_tenant!

    status, _, body = @middleware.call(env)

    assert_equal 404, status
    assert_equal "Tenant not found", body.first
    assert_nil Current.tenant
  end

  test "should handle errors gracefully" do
    # Test error handling by simulating a database error
    original_method = Tenant.method(:find_by_hostname!)
    Tenant.define_singleton_method(:find_by_hostname!) do |hostname|
      raise ActiveRecord::StatementInvalid, "Database connection lost"
    end

    env = { "HTTP_HOST" => "test.example.com" }
    status, headers, body = @middleware.call(env)

    # Should fallback to root tenant on error and return 404 since no tenant found
    assert_equal 404, status
    assert_equal "Tenant not found", body.first
    assert_nil Current.tenant

    # Restore original method
    Tenant.define_singleton_method(:find_by_hostname!, original_method)
  end

  test "should handle missing HTTP_HOST" do
    env = {}
    Current.reset_tenant!

    status, _, body = @middleware.call(env)

    # Should return 404 for missing host - no fallback
    assert_equal 404, status
    assert_equal "Tenant not found", body.first
    assert_nil Current.tenant
  end
end
