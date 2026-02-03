# frozen_string_literal: true

require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_category") do |t|
      t.hostname = "category-test.example.com"
      t.title = "Category Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "category-test.example.com"
    end

    Current.tenant = @tenant
    Current.site = @site

    @category = Category.new(
      tenant: @tenant,
      site: @site,
      name: "AI Tools",
      key: "ai_tools"
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @category.valid?, @category.errors.full_messages.join(", ")
  end

  test "should require name" do
    @category.name = nil
    assert_not @category.valid?
    assert_includes @category.errors[:name], "can't be blank"
  end

  test "should require key" do
    @category.key = nil
    assert_not @category.valid?
    assert_includes @category.errors[:key], "can't be blank"
  end

  test "should require unique key per site" do
    @category.save!
    duplicate = Category.new(
      tenant: @tenant,
      site: @site,
      name: "Different Name",
      key: "ai_tools"  # Same key
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "should allow same key in different sites" do
    @category.save!

    other_site = Site.create!(
      tenant: @tenant,
      name: "Other Site",
      primary_hostname: "other.example.com"
    )

    other_category = Category.new(
      tenant: @tenant,
      site: other_site,
      name: "AI Tools",
      key: "ai_tools"  # Same key, different site
    )

    Current.site = other_site
    assert other_category.valid?, other_category.errors.full_messages.join(", ")
  end

  # === Associations ===

  test "should have many listings" do
    @category.save!
    listing = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Test Tool",
      url_raw: "https://example.com/tool"
    )

    assert_includes @category.listings, listing
  end

  test "should destroy dependent listings" do
    @category.save!
    Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Test Tool",
      url_raw: "https://example.com/tool"
    )

    assert_difference "Listing.count", -1 do
      @category.destroy
    end
  end

  # === allow_paths ===

  test "should default allow_paths to true" do
    category = Category.new
    assert category.allow_paths
  end

  test "should validate allow_paths is boolean" do
    @category.allow_paths = true
    assert @category.valid?

    @category.allow_paths = false
    assert @category.valid?
  end

  # === Scopes ===

  test "allowing_paths scope returns categories with allow_paths true" do
    @category.allow_paths = true
    @category.save!

    root_only = Category.create!(
      tenant: @tenant,
      site: @site,
      name: "Root Only",
      key: "root_only",
      allow_paths: false
    )

    results = Category.allowing_paths
    assert_includes results, @category
    assert_not_includes results, root_only
  end

  test "root_domain_only scope returns categories with allow_paths false" do
    @category.allow_paths = true
    @category.save!

    root_only = Category.create!(
      tenant: @tenant,
      site: @site,
      name: "Root Only",
      key: "root_only",
      allow_paths: false
    )

    results = Category.root_domain_only
    assert_not_includes results, @category
    assert_includes results, root_only
  end

  # === URL Validation ===

  test "allows_url? returns true for any URL when allow_paths is true" do
    @category.allow_paths = true

    assert @category.allows_url?("https://example.com")
    assert @category.allows_url?("https://example.com/path")
    assert @category.allows_url?("https://example.com/path/to/page")
  end

  test "allows_url? returns true only for root URLs when allow_paths is false" do
    @category.allow_paths = false

    assert @category.allows_url?("https://example.com")
    assert @category.allows_url?("https://example.com/")
    assert_not @category.allows_url?("https://example.com/path")
    assert_not @category.allows_url?("https://example.com/path/to/page")
  end

  test "allows_url? handles invalid URLs gracefully" do
    @category.allow_paths = false

    assert_not @category.allows_url?(nil)
    assert_not @category.allows_url?("")
    assert_not @category.allows_url?("not-a-url")
    assert_not @category.allows_url?("javascript:alert(1)")
  end

  # === shown_fields ===

  test "shown_fields returns empty hash by default" do
    assert_equal({}, @category.shown_fields)
  end

  test "should validate shown_fields structure" do
    @category.shown_fields = "not a hash"
    assert_not @category.valid?
    assert_includes @category.errors[:shown_fields], "must be a valid JSON object"
  end

  test "should accept valid shown_fields hash" do
    @category.shown_fields = { "company" => true, "salary" => true }
    assert @category.valid?
  end
end
