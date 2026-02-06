# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id              :bigint           not null, primary key
#  hostname        :string           not null
#  last_checked_at :datetime
#  last_error      :text
#  primary         :boolean          default(FALSE), not null
#  status          :integer          default("pending_dns"), not null
#  verified        :boolean          default(FALSE), not null
#  verified_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  site_id         :bigint           not null
#
# Indexes
#
#  index_domains_on_hostname               (hostname) UNIQUE
#  index_domains_on_site_id                (site_id)
#  index_domains_on_site_id_and_verified   (site_id,verified)
#  index_domains_on_site_id_where_primary  (site_id) UNIQUE WHERE ("primary" = true)
#  index_domains_on_status                 (status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
require "test_helper"

class DomainTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_domain") do |t|
      t.hostname = "domain-test.example.com"
      t.title = "Domain Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "domain-test.example.com"
    end

    Current.tenant = @tenant

    @domain = Domain.new(
      site: @site,
      hostname: "test-domain.example.com"
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @domain.valid?, @domain.errors.full_messages.join(", ")
  end

  test "should require hostname" do
    @domain.hostname = nil
    assert_not @domain.valid?
    assert_includes @domain.errors[:hostname], "can't be blank"
  end

  test "should require unique hostname globally" do
    @domain.save!

    other_site = Site.create!(
      tenant: @tenant,
      name: "Other Site",
      slug: "other_site_domain"
    )

    duplicate = Domain.new(
      site: other_site,
      hostname: "test-domain.example.com"  # Same hostname
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:hostname], "has already been taken"
  end

  test "should validate hostname format" do
    @domain.hostname = "invalid hostname!"
    assert_not @domain.valid?
    assert_includes @domain.errors[:hostname], "must be a valid domain name"
  end

  test "should accept valid hostname formats" do
    valid_hostnames = [
      "example.com",
      "sub.example.com",
      "deep.sub.example.com",
      "example-with-dash.com",
      "123.example.com"
    ]

    valid_hostnames.each do |hostname|
      @domain.hostname = hostname
      assert @domain.valid?, "Expected #{hostname} to be valid but got: #{@domain.errors.full_messages.join(', ')}"
    end
  end

  # === Status ===

  test "should default to pending_dns status" do
    domain = Domain.new(site: @site, hostname: "new.example.com")
    domain.valid?  # Trigger before_validation
    assert_equal "pending_dns", domain.status
  end

  test "should have pending_dns status enum" do
    @domain.status = :pending_dns
    assert @domain.pending_dns?
  end

  test "should have verified_dns status enum" do
    @domain.status = :verified_dns
    assert @domain.verified_dns?
  end

  test "should have ssl_pending status enum" do
    @domain.status = :ssl_pending
    assert @domain.ssl_pending?
  end

  test "should have active status enum" do
    @domain.status = :active
    assert @domain.active?
  end

  test "should have failed status enum" do
    @domain.status = :failed
    assert @domain.failed?
  end

  # === Verified Status ===

  test "should not be verified by default" do
    assert_not @domain.verified?
  end

  test "verify! marks domain as verified" do
    @domain.save!
    @domain.verify!

    assert @domain.verified?
    assert_not_nil @domain.verified_at
  end

  test "unverify! clears verified status" do
    @domain.save!
    @domain.verify!
    @domain.unverify!

    assert_not @domain.verified?
    assert_nil @domain.verified_at
  end

  # === Primary Domain ===

  test "should not be primary by default" do
    assert_not @domain.primary?
  end

  test "make_primary! sets domain as primary" do
    @domain.save!
    @domain.make_primary!

    assert @domain.primary?
  end

  test "make_primary! unsets other primary domains for same site" do
    @domain.primary = true
    @domain.save!

    other_domain = Domain.create!(
      site: @site,
      hostname: "other-domain.example.com"
    )
    other_domain.make_primary!

    @domain.reload
    assert_not @domain.primary?
    assert other_domain.primary?
  end

  test "should only allow one primary domain per site" do
    @domain.primary = true
    @domain.save!

    other_domain = Domain.new(
      site: @site,
      hostname: "other.example.com",
      primary: true
    )
    assert_not other_domain.valid?
    assert_includes other_domain.errors[:primary], "only one domain can be marked as primary per site"
  end

  # === Hostname Normalization ===

  test "normalizes hostname to lowercase" do
    @domain.hostname = "TEST-DOMAIN.EXAMPLE.COM"
    @domain.save!
    assert_equal "test-domain.example.com", @domain.hostname
  end

  test "normalizes hostname by removing trailing dots" do
    @domain.hostname = "test-domain.example.com."
    @domain.save!
    assert_equal "test-domain.example.com", @domain.hostname
  end

  test "normalizes hostname by removing port" do
    @domain.hostname = "test-domain.example.com:3000"
    @domain.save!
    assert_equal "test-domain.example.com", @domain.hostname
  end

  # === Class Methods ===

  test "normalize_hostname handles nil" do
    assert_nil Domain.normalize_hostname(nil)
  end

  test "normalize_hostname handles blank string" do
    assert_nil Domain.normalize_hostname("")
    assert_nil Domain.normalize_hostname("   ")
  end

  test "normalize_hostname lowercases and strips" do
    assert_equal "example.com", Domain.normalize_hostname("EXAMPLE.COM")
    assert_equal "example.com", Domain.normalize_hostname("example.com.")
    assert_equal "example.com", Domain.normalize_hostname("example.com:8080")
  end

  test "find_by_hostname! finds domain with normalized hostname" do
    @domain.save!
    found = Domain.find_by_hostname!("TEST-DOMAIN.EXAMPLE.COM")
    assert_equal @domain, found
  end

  test "find_by_hostname! raises for unknown hostname" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Domain.find_by_hostname!("nonexistent.example.com")
    end
  end

  test "find_by_hostname returns nil for unknown hostname" do
    assert_nil Domain.find_by_hostname("nonexistent.example.com")
  end

  # === Scopes ===

  test "primary scope returns only primary domains" do
    @domain.primary = true
    @domain.save!

    other = Domain.create!(
      site: @site,
      hostname: "other.example.com",
      primary: false
    )

    # Clear existing primary if any, then set ours
    Domain.where.not(id: @domain.id).where(site: @site).update_all(primary: false)

    results = Domain.primary
    assert_includes results, @domain
    assert_not_includes results, other
  end

  test "verified scope returns only verified domains" do
    @domain.verified = true
    @domain.save!

    unverified = Domain.create!(
      site: @site,
      hostname: "unverified.example.com",
      verified: false
    )

    results = Domain.verified
    assert_includes results, @domain
    assert_not_includes results, unverified
  end

  test "unverified scope returns only unverified domains" do
    @domain.verified = false
    @domain.save!

    verified_domain = Domain.create!(
      site: @site,
      hostname: "verified.example.com",
      verified: true
    )

    results = Domain.unverified
    assert_includes results, @domain
    assert_not_includes results, verified_domain
  end

  # === Apex Domain Detection ===

  test "apex_domain? returns true for two-part domains" do
    @domain.hostname = "example.com"
    assert @domain.apex_domain?
  end

  test "apex_domain? returns false for subdomains" do
    @domain.hostname = "sub.example.com"
    assert_not @domain.apex_domain?
  end

  test "apex_domain? returns false for deep subdomains" do
    @domain.hostname = "deep.sub.example.com"
    assert_not @domain.apex_domain?
  end

  # === Status Helpers ===

  test "next_step returns appropriate message for pending_dns" do
    @domain.status = :pending_dns
    assert_includes @domain.next_step, "Configure DNS"
  end

  test "next_step returns appropriate message for verified_dns" do
    @domain.status = :verified_dns
    assert_includes @domain.next_step, "DNS verified"
  end

  test "next_step returns appropriate message for active" do
    @domain.status = :active
    assert_includes @domain.next_step, "ready to use"
  end

  test "next_step returns appropriate message for failed" do
    @domain.status = :failed
    assert_includes @domain.next_step, "failed"
  end

  test "status_color returns yellow for pending_dns" do
    @domain.status = :pending_dns
    assert_equal "yellow", @domain.status_color
  end

  test "status_color returns green for active" do
    @domain.status = :active
    assert_equal "green", @domain.status_color
  end

  test "status_color returns red for failed" do
    @domain.status = :failed
    assert_equal "red", @domain.status_color
  end
end
