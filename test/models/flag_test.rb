# frozen_string_literal: true

# == Schema Information
#
# Table name: flags
#
#  id             :bigint           not null, primary key
#  details        :text
#  flaggable_type :string           not null
#  reason         :integer          default("spam"), not null
#  reviewed_at    :datetime
#  status         :integer          default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  flaggable_id   :bigint           not null
#  reviewed_by_id :bigint
#  site_id        :bigint           not null
#  user_id        :bigint           not null
#
# Indexes
#
#  index_flags_on_flaggable        (flaggable_type,flaggable_id)
#  index_flags_on_reviewed_by_id   (reviewed_by_id)
#  index_flags_on_site_and_status  (site_id,status)
#  index_flags_on_site_id          (site_id)
#  index_flags_on_user_id          (user_id)
#  index_flags_uniqueness          (site_id,user_id,flaggable_type,flaggable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (reviewed_by_id => users.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class FlagTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_flag") do |t|
      t.hostname = "flag-test.example.com"
      t.title = "Flag Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "flag-test.example.com"
    end

    @category = Category.find_or_create_by!(site: @site, tenant: @tenant, key: "tools") do |c|
      c.name = "Tools"
    end

    @source = Source.find_or_create_by!(site: @site, tenant: @tenant, name: "Test Source", kind: :rss) do |s|
      s.feed_url = "https://example.com/feed.xml"
    end

    @flagger = User.find_or_create_by!(email: "flagger@example.com") do |u|
      u.password = "password123"
    end

    @content_owner = User.find_or_create_by!(email: "content-owner@example.com") do |u|
      u.password = "password123"
    end

    @reviewer = User.find_or_create_by!(email: "flag-reviewer@example.com") do |u|
      u.password = "password123"
    end

    Current.tenant = @tenant
    Current.site = @site

    @content_item = ContentItem.find_or_create_by!(
      site: @site,
      source: @source,
      url_canonical: "https://example.com/flaggable-content"
    ) do |c|
      c.url_raw = "https://example.com/flaggable-content"
      c.raw_payload = {}
      c.tags = []
    end

    @flag = Flag.new(
      site: @site,
      user: @flagger,
      flaggable: @content_item,
      reason: :spam,
      details: "This looks like spam"
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @flag.valid?, @flag.errors.full_messages.join(", ")
  end

  test "should require reason" do
    @flag.reason = nil
    assert_not @flag.valid?
    assert_includes @flag.errors[:reason], "can't be blank"
  end

  test "should validate details length" do
    @flag.details = "a" * 1001
    assert_not @flag.valid?
    assert_includes @flag.errors[:details], "is too long (maximum is 1000 characters)"
  end

  test "should prevent duplicate flags from same user" do
    @flag.save!

    duplicate = Flag.new(
      site: @site,
      user: @flagger,
      flaggable: @content_item,
      reason: :harassment
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already flagged this content"
  end

  test "should allow flags from different users on same content" do
    @flag.save!

    other_user = User.create!(
      email: "other-flagger@example.com",
      password: "password123"
    )

    other_flag = Flag.new(
      site: @site,
      user: other_user,
      flaggable: @content_item,
      reason: :harassment
    )
    assert other_flag.valid?
  end

  # === Reason Enum ===

  test "should have spam reason" do
    @flag.reason = :spam
    assert @flag.spam?
  end

  test "should have harassment reason" do
    @flag.reason = :harassment
    assert @flag.harassment?
  end

  test "should have misinformation reason" do
    @flag.reason = :misinformation
    assert @flag.misinformation?
  end

  test "should have inappropriate reason" do
    @flag.reason = :inappropriate
    assert @flag.inappropriate?
  end

  test "should have other reason" do
    @flag.reason = :other
    assert @flag.other?
  end

  # === Status Enum ===

  test "should default to pending status" do
    flag = Flag.new
    assert_equal "pending", flag.status
  end

  test "should have pending status" do
    @flag.status = :pending
    assert @flag.pending?
  end

  test "should have reviewed status" do
    @flag.status = :reviewed
    assert @flag.reviewed?
  end

  test "should have dismissed status" do
    @flag.status = :dismissed
    assert @flag.dismissed?
  end

  test "should have action_taken status" do
    @flag.status = :action_taken
    assert @flag.action_taken?
  end

  # === Scopes ===

  test "pending scope returns only pending flags" do
    @flag.save!

    reviewed = Flag.create!(
      site: @site,
      user: User.create!(email: "r1@example.com", password: "password123"),
      flaggable: @content_item,
      reason: :spam,
      status: :reviewed,
      reviewed_by: @reviewer,
      reviewed_at: Time.current
    )

    results = Flag.pending
    assert_includes results, @flag
    assert_not_includes results, reviewed
  end

  test "resolved scope excludes pending flags" do
    @flag.save!

    reviewed = Flag.create!(
      site: @site,
      user: User.create!(email: "r2@example.com", password: "password123"),
      flaggable: @content_item,
      reason: :spam,
      status: :reviewed,
      reviewed_by: @reviewer,
      reviewed_at: Time.current
    )

    results = Flag.resolved
    assert_not_includes results, @flag
    assert_includes results, reviewed
  end

  test "for_content_items scope filters by type" do
    @flag.save!

    # Create a note to flag
    note = Note.create!(
      site: @site,
      user: @content_owner,
      body: "Test note"
    )

    note_flag = Flag.create!(
      site: @site,
      user: @flagger,
      flaggable: note,
      reason: :spam
    )

    results = Flag.for_content_items
    assert_includes results, @flag
    assert_not_includes results, note_flag
  end

  test "recent scope orders by created_at desc" do
    @flag.save!

    newer = Flag.create!(
      site: @site,
      user: User.create!(email: "newer@example.com", password: "password123"),
      flaggable: @content_item,
      reason: :harassment
    )

    results = Flag.recent.limit(2)
    assert_equal newer, results.first
  end

  # === Resolve Methods ===

  test "resolve! updates status and reviewer" do
    @flag.save!
    @flag.resolve!(@reviewer)

    assert @flag.reviewed?
    assert_equal @reviewer, @flag.reviewed_by
    assert_not_nil @flag.reviewed_at
  end

  test "resolve! with action_taken status" do
    @flag.save!
    @flag.resolve!(@reviewer, action: :action_taken)

    assert @flag.action_taken?
  end

  test "dismiss! sets dismissed status" do
    @flag.save!
    @flag.dismiss!(@reviewer)

    assert @flag.dismissed?
    assert_equal @reviewer, @flag.reviewed_by
  end

  # === Helper Methods ===

  test "reviewed? returns false for pending" do
    @flag.status = :pending
    assert_not @flag.reviewed?
  end

  test "reviewed? returns true for non-pending" do
    @flag.status = :reviewed
    assert @flag.reviewed?

    @flag.status = :dismissed
    assert @flag.reviewed?

    @flag.status = :action_taken
    assert @flag.reviewed?
  end

  test "content_item? returns true for ContentItem flaggable" do
    @flag.flaggable = @content_item
    assert @flag.content_item?
  end

  test "content_item? returns false for other types" do
    note = Note.create!(
      site: @site,
      user: @content_owner,
      body: "Test note"
    )
    @flag.flaggable = note
    assert_not @flag.content_item?
  end

  # === Polymorphic Association ===

  test "can flag content items" do
    @flag.flaggable = @content_item
    @flag.save!
    assert_equal @content_item, @flag.flaggable
  end

  test "can flag notes" do
    note = Note.create!(
      site: @site,
      user: @content_owner,
      body: "Flaggable note"
    )

    flag = Flag.create!(
      site: @site,
      user: @flagger,
      flaggable: note,
      reason: :inappropriate
    )

    assert_equal note, flag.flaggable
    assert_equal "Note", flag.flaggable_type
  end
end
