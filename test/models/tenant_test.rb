# frozen_string_literal: true

# == Schema Information
#
# Table name: tenants
#
#  id          :bigint           not null, primary key
#  description :text
#  hostname    :string           not null
#  logo_url    :string
#  settings    :jsonb            not null
#  slug        :string           not null
#  status      :integer          default("enabled"), not null
#  title       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_tenants_on_hostname  (hostname) UNIQUE
#  index_tenants_on_slug      (slug) UNIQUE
#  index_tenants_on_status    (status)
#
require "test_helper"

class TenantTest < ActiveSupport::TestCase
  def setup
        @tenant = Tenant.new(
          hostname: "test.example.com",
          slug: "test",
          title: "Test Tenant",
          description: "A test tenant",
          status: "enabled"
        )
  end

  test "should be valid with valid attributes" do
    assert @tenant.valid?
  end

  test "should require hostname" do
    @tenant.hostname = nil
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:hostname], "can't be blank"
  end

  test "should require unique hostname" do
    @tenant.save!
    duplicate_tenant = Tenant.new(
      hostname: "test.example.com",
      slug: "test2",
      title: "Another Test"
    )
    assert_not duplicate_tenant.valid?
    assert_includes duplicate_tenant.errors[:hostname], "has already been taken"
  end

  test "should validate hostname format" do
    @tenant.hostname = "invalid hostname!"
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:hostname], "must be a valid domain name"
  end

  test "should require slug" do
    @tenant.slug = nil
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:slug], "can't be blank"
  end

  test "should require unique slug" do
    @tenant.save!
    duplicate_tenant = Tenant.new(
      hostname: "test2.example.com",
      slug: "test",
      title: "Another Test"
    )
    assert_not duplicate_tenant.valid?
    assert_includes duplicate_tenant.errors[:slug], "has already been taken"
  end

  test "should validate slug format" do
    @tenant.slug = "invalid-slug!"
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:slug], "must contain only lowercase letters, numbers, and underscores"
  end

  test "should require title" do
    @tenant.title = nil
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:title], "can't be blank"
  end


  test "should validate status presence" do
    @tenant.status = nil
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:status], "can't be blank"
  end

  test "should have default values" do
    tenant = Tenant.new(hostname: "test.com", slug: "test", title: "Test")
    assert_equal({}, tenant.settings)
    assert_equal "enabled", tenant.status
  end

  test "should find by hostname" do
    @tenant.save!
    found_tenant = Tenant.find_by_hostname!("test.example.com")
    assert_equal @tenant, found_tenant
  end

  test "should raise error when finding non-existent hostname" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Tenant.find_by_hostname!("nonexistent.com")
    end
  end

  test "should find root tenant" do
    # Prefer seeded root tenant if present to avoid uniqueness conflicts
    root_tenant = Tenant.find_or_create_by!(
      slug: "root"
    ) do |t|
      t.hostname = "root.example.com"
      t.title = "Root Tenant"
    end
    assert_equal root_tenant, Tenant.root_tenant
  end

  test "should identify root tenant" do
    @tenant.slug = "root"
    assert @tenant.root?
  end

  test "should not identify non-root tenant as root" do
    assert_not @tenant.root?
  end

  test "should handle settings access" do
    @tenant.settings = { "theme" => { "color" => "blue" } }
    assert_equal "blue", @tenant.setting("theme.color")
    assert_equal "default", @tenant.setting("nonexistent", "default")
  end

  test "should update settings" do
    @tenant.save!
    @tenant.update_setting("theme.color", "red")
    assert_equal "red", @tenant.reload.setting("theme.color")
  end

  test "should scope active tenants" do
    active_tenant = Tenant.create!(
      hostname: "active.example.com",
      slug: "active",
      title: "Active Tenant",
      status: "enabled"
    )
    inactive_tenant = Tenant.create!(
      hostname: "inactive.example.com",
      slug: "inactive",
      title: "Inactive Tenant",
      status: "disabled"
    )
    private_tenant = Tenant.create!(
      hostname: "private.example.com",
      slug: "private",
      title: "Private Tenant",
      status: "private_access"
    )

    active_tenants = Tenant.active
    assert_includes active_tenants, active_tenant
    assert_not_includes active_tenants, inactive_tenant
    assert_not_includes active_tenants, private_tenant
  end

  test "should scope by hostname" do
    @tenant.save!
    found_tenants = Tenant.by_hostname("test.example.com")
    assert_includes found_tenants, @tenant
  end

  test "should have status enum methods" do
    @tenant.status = "enabled"
    assert @tenant.enabled?
    assert @tenant.publicly_accessible?
    assert_not @tenant.requires_login?

    @tenant.status = "disabled"
    assert @tenant.disabled?
    assert_not @tenant.publicly_accessible?
    assert_not @tenant.requires_login?

    @tenant.status = "private_access"
    assert @tenant.private_access?
    assert_not @tenant.publicly_accessible?
    assert @tenant.requires_login?
  end


  test "should validate title length" do
    @tenant.title = "a" * 256
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "should validate description length" do
    @tenant.description = "a" * 1001
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:description], "is too long (maximum is 1000 characters)"
  end

  test "should validate logo URL format" do
    @tenant.logo_url = "not-a-url"
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:logo_url], "must be a valid URL"
  end

  test "should validate settings structure" do
    @tenant.settings = "invalid"
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:settings], "must be a valid JSON object"
  end

  test "should validate theme colors" do
    @tenant.settings = {
      "theme" => {
        "primary_color" => "invalid_color"
      }
    }
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:settings], "primary_color must be a valid Tailwind color"
  end

  test "should validate categories structure" do
    @tenant.settings = {
      "categories" => {
        "news" => "invalid"
      }
    }
    assert_not @tenant.valid?
    assert_includes @tenant.errors[:settings], "category 'news' must have an 'enabled' property"
  end


  test "should clear cache on save" do
    # Use memory store for testing cache functionality
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    
    tenant = Tenant.create!(
      hostname: "cache-test.example.com",
      slug: "cache_test",
      title: "Cache Test Tenant",
      settings: { theme: { primary_color: "blue" } }
    )
    
    # Verify cache is populated by calling the method that uses cache
    cached_tenant = Tenant.find_by_hostname!("cache-test.example.com")
    assert_equal tenant, cached_tenant
    
    # Update tenant and verify cache is cleared
    tenant.update!(title: "Updated Cache Test Tenant")
    
    # Cache should be cleared and repopulated
    cached_tenant = Tenant.find_by_hostname!("cache-test.example.com")
    assert_equal "Updated Cache Test Tenant", cached_tenant.title
    
    # Restore original cache
    Rails.cache = original_cache
  end
end
