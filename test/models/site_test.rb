# frozen_string_literal: true

require "test_helper"

class SiteTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_site") do |t|
      t.hostname = "site-test.example.com"
      t.title = "Site Test Tenant"
    end

    Current.tenant = @tenant

    @site = Site.new(
      tenant: @tenant,
      name: "Test Site",
      slug: "test_site",
      description: "A test site"
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @site.valid?, @site.errors.full_messages.join(", ")
  end

  test "should require name" do
    @site.name = nil
    assert_not @site.valid?
    assert_includes @site.errors[:name], "can't be blank"
  end

  test "should require slug" do
    @site.slug = nil
    assert_not @site.valid?
    assert_includes @site.errors[:slug], "can't be blank"
  end

  test "should require unique slug per tenant" do
    @site.save!
    duplicate = Site.new(
      tenant: @tenant,
      name: "Another Site",
      slug: "test_site"  # Same slug
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:slug], "has already been taken"
  end

  test "should validate slug format - lowercase only" do
    @site.slug = "Test_Site"
    assert_not @site.valid?
    assert_includes @site.errors[:slug], "must contain only lowercase letters, numbers, and underscores"
  end

  test "should validate slug format - no special characters" do
    @site.slug = "test-site"
    assert_not @site.valid?
    assert_includes @site.errors[:slug], "must contain only lowercase letters, numbers, and underscores"
  end

  test "should validate name length" do
    @site.name = "a" * 256
    assert_not @site.valid?
    assert_includes @site.errors[:name], "is too long (maximum is 255 characters)"
  end

  test "should validate description length" do
    @site.description = "a" * 1001
    assert_not @site.valid?
    assert_includes @site.errors[:description], "is too long (maximum is 1000 characters)"
  end

  # === Status ===

  test "should default to enabled status" do
    site = Site.new
    assert_equal "enabled", site.status
  end

  test "should allow enabled status" do
    @site.status = :enabled
    assert @site.enabled?
  end

  test "should allow disabled status" do
    @site.status = :disabled
    assert @site.disabled?
  end

  test "should allow private_access status" do
    @site.status = :private_access
    assert @site.private_access?
  end

  # === Scopes ===

  test "active scope returns only enabled sites" do
    @site.status = :enabled
    @site.save!

    disabled_site = Site.create!(
      tenant: @tenant,
      name: "Disabled Site",
      slug: "disabled_site",
      status: :disabled
    )

    results = Site.active
    assert_includes results, @site
    assert_not_includes results, disabled_site
  end

  test "by_tenant scope filters by tenant" do
    @site.save!

    other_tenant = Tenant.create!(
      hostname: "other.example.com",
      slug: "other",
      title: "Other Tenant"
    )

    other_site = Site.create!(
      tenant: other_tenant,
      name: "Other Site",
      slug: "other_site"
    )

    results = Site.by_tenant(@tenant)
    assert_includes results, @site
    assert_not_includes results, other_site
  end

  # === Config ===

  test "config returns empty hash by default" do
    assert_equal({}, @site.config)
  end

  test "should validate config structure" do
    @site.config = "not a hash"
    assert_not @site.valid?
    assert_includes @site.errors[:config], "must be a valid JSON object"
  end

  test "topics returns empty array by default" do
    assert_equal [], @site.topics
  end

  test "topics returns configured topics" do
    @site.config = { "topics" => %w[ai ml data] }
    assert_equal %w[ai ml data], @site.topics
  end

  # === Feature Flags ===

  test "discussions_enabled? returns false by default" do
    assert_not @site.discussions_enabled?
  end

  test "discussions_enabled? returns true when enabled in config" do
    @site.config = { "features" => { "discussions" => true } }
    assert @site.discussions_enabled?
  end

  test "streaming_enabled? returns false by default" do
    assert_not @site.streaming_enabled?
  end

  test "streaming_enabled? returns true when enabled in config" do
    @site.config = { "features" => { "live_streaming" => true } }
    assert @site.streaming_enabled?
  end

  test "products_enabled? returns false by default" do
    assert_not @site.products_enabled?
  end

  test "products_enabled? returns true when enabled in config" do
    @site.config = { "features" => { "digital_products" => true } }
    assert @site.products_enabled?
  end

  # === Primary Hostname ===

  test "primary_hostname returns nil without domain" do
    @site.save!
    assert_nil @site.primary_hostname
  end

  test "primary_hostname returns domain hostname" do
    @site.save!
    Domain.create!(
      site: @site,
      hostname: "test.example.com",
      primary: true
    )
    assert_equal "test.example.com", @site.primary_hostname
  end

  # === Find by Hostname ===

  test "find_by_hostname! returns site for valid hostname" do
    @site.save!
    Domain.create!(
      site: @site,
      hostname: "find-test.example.com",
      primary: true
    )

    found = Site.find_by_hostname!("find-test.example.com")
    assert_equal @site, found
  end

  test "find_by_hostname! raises for unknown hostname" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Site.find_by_hostname!("nonexistent.example.com")
    end
  end

  # === Associations ===

  test "has many categories" do
    @site.save!
    category = Category.create!(
      tenant: @tenant,
      site: @site,
      name: "Test Category",
      key: "test_cat"
    )

    Current.site = @site
    assert_includes @site.categories, category
  end

  test "has many listings through categories" do
    @site.save!
    Current.site = @site

    category = Category.create!(
      tenant: @tenant,
      site: @site,
      name: "Test Category",
      key: "test_cat_listing"
    )

    listing = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: category,
      title: "Test Tool",
      url_raw: "https://example.com/tool"
    )

    assert_includes @site.listings, listing
  end

  # === Callbacks ===

  test "creates default subscriber segments after create" do
    @site.save!
    Current.site = @site

    # Check that default segments were created
    segments = @site.subscriber_segments
    assert segments.any?, "Expected default subscriber segments to be created"
  end
end
