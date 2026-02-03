# frozen_string_literal: true

require "test_helper"

class SubmissionTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_submission") do |t|
      t.hostname = "submission-test.example.com"
      t.title = "Submission Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "submission-test.example.com"
    end

    @category = Category.find_or_create_by!(site: @site, tenant: @tenant, key: "tools") do |c|
      c.name = "Tools"
    end

    @user = User.find_or_create_by!(email: "submitter@example.com") do |u|
      u.password = "password123"
    end

    @reviewer = User.find_or_create_by!(email: "reviewer@example.com") do |u|
      u.password = "password123"
    end

    Current.tenant = @tenant
    Current.site = @site

    @submission = Submission.new(
      site: @site,
      user: @user,
      category: @category,
      title: "Awesome Tool",
      url: "https://example.com/tool",
      description: "A great tool for testing",
      listing_type: :tool
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @submission.valid?, @submission.errors.full_messages.join(", ")
  end

  test "should require title" do
    @submission.title = nil
    assert_not @submission.valid?
    assert_includes @submission.errors[:title], "can't be blank"
  end

  test "should require url" do
    @submission.url = nil
    assert_not @submission.valid?
    assert_includes @submission.errors[:url], "can't be blank"
  end

  test "should validate url format" do
    @submission.url = "not-a-url"
    assert_not @submission.valid?
    assert @submission.errors[:url].any?
  end

  test "should accept valid HTTP url" do
    @submission.url = "http://example.com/tool"
    assert @submission.valid?
  end

  test "should accept valid HTTPS url" do
    @submission.url = "https://example.com/tool"
    assert @submission.valid?
  end

  test "should validate title length" do
    @submission.title = "a" * 256
    assert_not @submission.valid?
    assert_includes @submission.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "should validate description length" do
    @submission.description = "a" * 2001
    assert_not @submission.valid?
    assert_includes @submission.errors[:description], "is too long (maximum is 2000 characters)"
  end

  # === Status Enum ===

  test "should default to pending status" do
    submission = Submission.new
    assert_equal "pending", submission.status
  end

  test "should have pending status" do
    @submission.status = :pending
    assert @submission.pending?
  end

  test "should have approved status" do
    @submission.status = :approved
    assert @submission.approved?
  end

  test "should have rejected status" do
    @submission.status = :rejected
    assert @submission.rejected?
  end

  # === Listing Type Enum ===

  test "should default to tool listing type" do
    submission = Submission.new
    assert_equal "tool", submission.listing_type
  end

  test "should allow job listing type" do
    @submission.listing_type = :job
    assert @submission.job?
  end

  test "should allow service listing type" do
    @submission.listing_type = :service
    assert @submission.service?
  end

  # === Scopes ===

  test "recent scope orders by created_at desc" do
    @submission.save!

    newer = Submission.create!(
      site: @site,
      user: @user,
      category: @category,
      title: "Newer Tool",
      url: "https://example.com/newer"
    )

    results = Submission.recent.limit(2)
    assert_equal newer, results.first
  end

  test "needs_review scope returns pending submissions" do
    @submission.save!

    approved = Submission.create!(
      site: @site,
      user: @user,
      category: @category,
      title: "Approved Tool",
      url: "https://example.com/approved",
      status: :approved
    )

    results = Submission.needs_review
    assert_includes results, @submission
    assert_not_includes results, approved
  end

  test "by_user scope filters by user" do
    @submission.save!

    other_user = User.create!(
      email: "other-submitter@example.com",
      password: "password123"
    )

    other_submission = Submission.create!(
      site: @site,
      user: other_user,
      category: @category,
      title: "Other Tool",
      url: "https://example.com/other"
    )

    results = Submission.by_user(@user)
    assert_includes results, @submission
    assert_not_includes results, other_submission
  end

  # === URL Normalization ===

  test "normalizes url by stripping whitespace" do
    @submission.url = "  https://example.com/tool  "
    @submission.save!
    assert_equal "https://example.com/tool", @submission.url
  end

  test "normalizes url by adding https prefix" do
    @submission.url = "example.com/tool"
    @submission.save!
    assert_equal "https://example.com/tool", @submission.url
  end

  test "preserves http prefix" do
    @submission.url = "http://example.com/tool"
    @submission.save!
    assert_equal "http://example.com/tool", @submission.url
  end

  # === Approve ===

  test "approve! creates listing and updates status" do
    @submission.save!

    assert_difference "Listing.count", 1 do
      listing = @submission.approve!(reviewer: @reviewer, notes: "Looks good")

      @submission.reload
      assert @submission.approved?
      assert_equal @reviewer, @submission.reviewer
      assert_equal "Looks good", @submission.reviewer_notes
      assert_not_nil @submission.reviewed_at
      assert_equal listing, @submission.listing
    end
  end

  test "approve! creates listing with correct attributes" do
    @submission.save!

    listing = @submission.approve!(reviewer: @reviewer)

    assert_equal @site, listing.site
    assert_equal @category, listing.category
    assert_equal @submission.title, listing.title
    assert_equal @submission.description, listing.description
    assert_equal @submission.listing_type, listing.listing_type
    assert_not_nil listing.published_at
  end

  # === Reject ===

  test "reject! updates status without creating listing" do
    @submission.save!

    assert_no_difference "Listing.count" do
      @submission.reject!(reviewer: @reviewer, notes: "Not appropriate")
    end

    @submission.reload
    assert @submission.rejected?
    assert_equal @reviewer, @submission.reviewer
    assert_equal "Not appropriate", @submission.reviewer_notes
    assert_not_nil @submission.reviewed_at
    assert_nil @submission.listing
  end

  # === Create Listing ===

  test "create_listing! creates a new listing" do
    @submission.save!

    listing = @submission.create_listing!

    assert listing.persisted?
    assert_equal @submission.title, listing.title
    assert_equal @submission.url, listing.url_canonical
    assert_equal @submission.category, listing.category
  end

  # === Associations ===

  test "belongs to user" do
    @submission.save!
    assert_equal @user, @submission.user
  end

  test "belongs to category" do
    @submission.save!
    assert_equal @category, @submission.category
  end

  test "belongs to reviewer" do
    @submission.save!
    @submission.approve!(reviewer: @reviewer)
    assert_equal @reviewer, @submission.reviewer
  end

  test "belongs to listing when approved" do
    @submission.save!
    listing = @submission.approve!(reviewer: @reviewer)
    assert_equal listing, @submission.listing
  end
end
