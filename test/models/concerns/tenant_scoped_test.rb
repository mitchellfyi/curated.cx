# frozen_string_literal: true

require "test_helper"

# Create a test model to test the TenantScoped concern
class TestTenantScopedModel < ApplicationRecord
  include TenantScoped

  # Create a temporary table for testing without foreign key constraints
  def self.create_test_table
    connection.create_table :test_tenant_scoped_models, temporary: true do |t|
      t.bigint :tenant_id, null: false
      t.string :name
      t.timestamps
    end
  end

  def self.drop_test_table
    connection.drop_table :test_tenant_scoped_models, if_exists: true
  end
end

class TenantScopedTest < ActiveSupport::TestCase
  def setup
    TestTenantScopedModel.create_test_table

    @tenant1 = Tenant.create!(
      hostname: "tenant1.example.com",
      slug: "tenant1",
      title: "Tenant 1"
    )
    @tenant2 = Tenant.create!(
      hostname: "tenant2.example.com",
      slug: "tenant2",
      title: "Tenant 2"
    )
  end

  def teardown
    TestTenantScopedModel.drop_test_table
  end

  test "should validate tenant presence" do
    Current.reset_tenant!
    model = TestTenantScopedModel.new
    assert_not model.valid?
    assert_includes model.errors[:tenant], "can't be blank"
  end

  test "should be valid with tenant" do
    Current.tenant = @tenant1
    model = TestTenantScopedModel.new(tenant: @tenant1, name: "Test")
    assert model.valid?
  end

  test "should scope queries by current tenant" do
    Current.tenant = @tenant1
    # Create a record for tenant1
    TestTenantScopedModel.create!(tenant: @tenant1, name: "Record 1")
    # Create a record for tenant2
    TestTenantScopedModel.create!(tenant: @tenant2, name: "Record 2")

    scoped_records = TestTenantScopedModel.all
    assert_equal 1, scoped_records.count
    assert_equal @tenant1, scoped_records.first.tenant
  end

  test "should allow unscoped queries" do
    Current.tenant = @tenant1
    # Create records for both tenants
    TestTenantScopedModel.create!(tenant: @tenant1, name: "Record 1")
    TestTenantScopedModel.create!(tenant: @tenant2, name: "Record 2")

    unscoped_records = TestTenantScopedModel.without_tenant_scope
    assert_equal 2, unscoped_records.count
  end

  test "should allow queries for specific tenant" do
    Current.tenant = @tenant1
    # Create records for both tenants
    TestTenantScopedModel.create!(tenant: @tenant1, name: "Record 1")
    TestTenantScopedModel.create!(tenant: @tenant2, name: "Record 2")

    tenant2_records = TestTenantScopedModel.for_tenant(@tenant2)
    assert_equal 1, tenant2_records.count
    assert_equal @tenant2, tenant2_records.first.tenant
  end

  test "should not scope when no current tenant" do
    Current.reset_tenant!
    # Should not raise error when no tenant is set
    assert_nothing_raised do
      TestTenantScopedModel.all
    end
  end
end
