# frozen_string_literal: true

# == Schema Information
#
# Table name: listings
#
#  id                         :bigint           not null, primary key
#  affiliate_attribution      :jsonb            not null
#  affiliate_url_template     :text
#  ai_summaries               :jsonb            not null
#  ai_tags                    :jsonb            not null
#  apply_url                  :text
#  body_html                  :text
#  body_text                  :text
#  company                    :string
#  description                :text
#  domain                     :string
#  expires_at                 :datetime
#  featured_from              :datetime
#  featured_until             :datetime
#  image_url                  :text
#  listing_type               :integer          default("tool"), not null
#  location                   :string
#  metadata                   :jsonb            not null
#  paid                       :boolean          default(FALSE), not null
#  payment_reference          :string
#  payment_status             :integer          default("unpaid"), not null
#  published_at               :datetime
#  salary_range               :string
#  scheduled_for              :datetime
#  site_name                  :string
#  title                      :string
#  url_canonical              :text             not null
#  url_raw                    :text             not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  category_id                :bigint           not null
#  featured_by_id             :bigint
#  site_id                    :bigint           not null
#  source_id                  :bigint
#  stripe_checkout_session_id :string
#  stripe_payment_intent_id   :string
#  tenant_id                  :bigint           not null
#
# Indexes
#
#  index_listings_on_category_id                 (category_id)
#  index_listings_on_category_published          (category_id,published_at)
#  index_listings_on_domain                      (domain)
#  index_listings_on_featured_by_id              (featured_by_id)
#  index_listings_on_payment_status              (payment_status)
#  index_listings_on_published_at                (published_at)
#  index_listings_on_scheduled_for               (scheduled_for) WHERE (scheduled_for IS NOT NULL)
#  index_listings_on_site_expires_at             (site_id,expires_at)
#  index_listings_on_site_featured_dates         (site_id,featured_from,featured_until)
#  index_listings_on_site_id                     (site_id)
#  index_listings_on_site_id_and_url_canonical   (site_id,url_canonical) UNIQUE
#  index_listings_on_site_listing_type           (site_id,listing_type)
#  index_listings_on_site_type_expires           (site_id,listing_type,expires_at)
#  index_listings_on_source_id                   (source_id)
#  index_listings_on_stripe_checkout_session_id  (stripe_checkout_session_id) UNIQUE WHERE (stripe_checkout_session_id IS NOT NULL)
#  index_listings_on_stripe_payment_intent_id    (stripe_payment_intent_id) UNIQUE WHERE (stripe_payment_intent_id IS NOT NULL)
#  index_listings_on_tenant_and_url_canonical    (tenant_id,url_canonical) UNIQUE
#  index_listings_on_tenant_domain_published     (tenant_id,domain,published_at)
#  index_listings_on_tenant_id                   (tenant_id)
#  index_listings_on_tenant_id_and_category_id   (tenant_id,category_id)
#  index_listings_on_tenant_id_and_source_id     (tenant_id,source_id)
#  index_listings_on_tenant_published_created    (tenant_id,published_at,created_at)
#  index_listings_on_tenant_title                (tenant_id,title)
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#  fk_rails_...  (featured_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
require "test_helper"

class ListingTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_listing") do |t|
      t.hostname = "listing-test.example.com"
      t.title = "Listing Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "listing-test.example.com"
    end

    @category = Category.find_or_create_by!(site: @site, tenant: @tenant, key: "tools") do |c|
      c.name = "Tools"
    end

    Current.tenant = @tenant
    Current.site = @site

    @listing = Listing.new(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Test Tool",
      url_raw: "https://example.com/tool",
      listing_type: :tool
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @listing.valid?, @listing.errors.full_messages.join(", ")
  end

  test "should require title" do
    @listing.title = nil
    assert_not @listing.valid?
    assert_includes @listing.errors[:title], "can't be blank"
  end

  test "should require url_raw" do
    @listing.url_raw = nil
    assert_not @listing.valid?
    assert_includes @listing.errors[:url_raw], "can't be blank"
  end

  test "should require category" do
    @listing.category = nil
    assert_not @listing.valid?
    assert_includes @listing.errors[:category], "must exist"
  end

  test "should require unique url_canonical per site" do
    @listing.save!
    duplicate = Listing.new(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Duplicate Tool",
      url_raw: "https://example.com/tool"  # Same URL
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:url_canonical], "has already been taken"
  end

  # === URL Canonicalization ===

  test "should canonicalize url on save" do
    @listing.url_raw = "https://EXAMPLE.COM/TOOL?ref=123"
    @listing.save!
    assert_equal "https://example.com/tool", @listing.url_canonical
  end

  test "should extract domain from canonical url" do
    @listing.save!
    assert_equal "example.com", @listing.domain
  end

  # === Listing Types ===

  test "should default to tool type" do
    listing = Listing.new
    assert_equal "tool", listing.listing_type
  end

  test "should allow job type" do
    @listing.listing_type = :job
    assert @listing.valid?
    assert @listing.job?
  end

  test "should allow service type" do
    @listing.listing_type = :service
    assert @listing.valid?
    assert @listing.service?
  end

  # === Published Status ===

  test "should not be published by default" do
    assert_not @listing.published?
  end

  test "should be published when published_at is set" do
    @listing.published_at = Time.current
    assert @listing.published?
  end

  test "published scope returns only published listings" do
    @listing.save!
    unpublished = @listing

    published = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Published Tool",
      url_raw: "https://example.com/published",
      published_at: Time.current
    )

    results = Listing.published
    assert_includes results, published
    assert_not_includes results, unpublished
  end

  # === Featured Status ===

  test "should not be featured by default" do
    assert_not @listing.featured?
  end

  test "should be featured when within featured date range" do
    @listing.featured_from = 1.day.ago
    @listing.featured_until = 1.day.from_now
    assert @listing.featured?
  end

  test "should not be featured when before featured_from" do
    @listing.featured_from = 1.day.from_now
    @listing.featured_until = 2.days.from_now
    assert_not @listing.featured?
  end

  test "should not be featured when after featured_until" do
    @listing.featured_from = 2.days.ago
    @listing.featured_until = 1.day.ago
    assert_not @listing.featured?
  end

  test "should be featured with no end date" do
    @listing.featured_from = 1.day.ago
    @listing.featured_until = nil
    assert @listing.featured?
  end

  # === Expiry ===

  test "should not be expired by default" do
    assert_not @listing.expired?
  end

  test "should be expired when expires_at is in the past" do
    @listing.expires_at = 1.day.ago
    assert @listing.expired?
  end

  test "should not be expired when expires_at is in the future" do
    @listing.expires_at = 1.day.from_now
    assert_not @listing.expired?
  end

  test "not_expired scope excludes expired listings" do
    @listing.save!

    expired = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Expired Tool",
      url_raw: "https://example.com/expired",
      expires_at: 1.day.ago
    )

    results = Listing.not_expired
    assert_includes results, @listing
    assert_not_includes results, expired
  end

  # === Affiliate ===

  test "should not have affiliate by default" do
    assert_not @listing.has_affiliate?
  end

  test "should have affiliate when template is set" do
    @listing.affiliate_url_template = "https://affiliate.com/?ref={ref}"
    assert @listing.has_affiliate?
  end

  # === Scheduling ===

  test "should not be scheduled by default" do
    assert_not @listing.scheduled?
  end

  test "should be scheduled when scheduled_for is in the future" do
    @listing.scheduled_for = 1.day.from_now
    assert @listing.scheduled?
  end

  test "should not be scheduled when scheduled_for is in the past" do
    @listing.scheduled_for = 1.day.ago
    assert_not @listing.scheduled?
  end

  # === Scopes ===

  test "jobs scope returns only job listings" do
    @listing.listing_type = :tool
    @listing.save!

    job = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Test Job",
      url_raw: "https://example.com/job",
      listing_type: :job
    )

    results = Listing.jobs
    assert_includes results, job
    assert_not_includes results, @listing
  end

  test "filtered scope applies multiple filters" do
    @listing.listing_type = :tool
    @listing.published_at = Time.current
    @listing.save!

    job = Listing.create!(
      tenant: @tenant,
      site: @site,
      category: @category,
      title: "Test Job",
      url_raw: "https://example.com/job",
      listing_type: :job,
      published_at: Time.current
    )

    # Filter by type
    results = Listing.filtered(type: "job")
    assert_includes results, job
    assert_not_includes results, @listing

    # Filter by category
    results = Listing.filtered(category_id: @category.id)
    assert_includes results, @listing
    assert_includes results, job
  end

  # === JSONB Fields ===

  test "ai_summaries returns empty hash by default" do
    assert_equal({}, @listing.ai_summaries)
  end

  test "ai_tags returns empty hash by default" do
    assert_equal({}, @listing.ai_tags)
  end

  test "metadata returns empty hash by default" do
    assert_equal({}, @listing.metadata)
  end

  test "should validate jsonb fields are hashes" do
    @listing.ai_summaries = "not a hash"
    assert_not @listing.valid?
    assert_includes @listing.errors[:ai_summaries], "must be a valid JSON object"
  end

  # === Delegation ===

  test "should delegate category_name" do
    @listing.save!
    assert_equal "Tools", @listing.category_name
  end

  # === Root Domain ===

  test "should extract root domain" do
    @listing.url_canonical = "https://subdomain.example.com/path"
    assert_equal "example.com", @listing.root_domain
  end

  test "should handle root domain for two-part domains" do
    @listing.url_canonical = "https://example.com/path"
    assert_equal "example.com", @listing.root_domain
  end
end
