# frozen_string_literal: true

require "test_helper"

class NoteTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_note") do |t|
      t.hostname = "note-test.example.com"
      t.title = "Note Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "note-test.example.com"
    end

    @user = User.find_or_create_by!(email: "note-author@example.com") do |u|
      u.password = "password123"
    end

    Current.tenant = @tenant
    Current.site = @site

    @note = Note.new(
      site: @site,
      user: @user,
      body: "This is a test note with some interesting content."
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @note.valid?, @note.errors.full_messages.join(", ")
  end

  test "should require body" do
    @note.body = nil
    assert_not @note.valid?
    assert_includes @note.errors[:body], "can't be blank"
  end

  test "should validate body length" do
    @note.body = "a" * 501
    assert_not @note.valid?
    assert_includes @note.errors[:body], "is too long (maximum is 500 characters)"
  end

  test "should accept body at max length" do
    @note.body = "a" * 500
    assert @note.valid?
  end

  # === Published Status ===

  test "should not be published by default" do
    assert @note.draft?
    assert_not @note.published?
  end

  test "should be published when published_at is set" do
    @note.published_at = Time.current
    assert @note.published?
    assert_not @note.draft?
  end

  test "publish! sets published_at" do
    @note.save!
    @note.publish!

    assert @note.published?
    assert_not_nil @note.published_at
  end

  test "unpublish! clears published_at" do
    @note.published_at = Time.current
    @note.save!
    @note.unpublish!

    assert_not @note.published?
    assert_nil @note.published_at
  end

  # === Hidden Status ===

  test "should not be hidden by default" do
    assert_not @note.hidden?
  end

  test "hide! sets hidden_at and hidden_by" do
    admin = User.create!(email: "note-admin@example.com", password: "password123")
    @note.save!
    @note.hide!(admin)

    assert @note.hidden?
    assert_not_nil @note.hidden_at
    assert_equal admin, @note.hidden_by
  end

  test "unhide! clears hidden_at and hidden_by" do
    admin = User.create!(email: "unhide-admin@example.com", password: "password123")
    @note.save!
    @note.hide!(admin)
    @note.unhide!

    assert_not @note.hidden?
    assert_nil @note.hidden_at
    assert_nil @note.hidden_by
  end

  # === Reposts ===

  test "should not be a repost by default" do
    assert_not @note.repost?
  end

  test "should be a repost when repost_of is set" do
    original = Note.create!(
      site: @site,
      user: @user,
      body: "Original note"
    )

    @note.repost_of = original
    assert @note.repost?
  end

  test "original_note returns self for original notes" do
    @note.save!
    assert_equal @note, @note.original_note
  end

  test "original_note returns repost_of for reposts" do
    original = Note.create!(
      site: @site,
      user: @user,
      body: "Original note"
    )

    @note.repost_of = original
    @note.save!

    assert_equal original, @note.original_note
  end

  test "cannot repost a repost" do
    original = Note.create!(
      site: @site,
      user: @user,
      body: "Original note"
    )

    repost = Note.create!(
      site: @site,
      user: @user,
      body: "First repost",
      repost_of: original
    )

    second_repost = Note.new(
      site: @site,
      user: @user,
      body: "Second repost",
      repost_of: repost
    )

    assert_not second_repost.valid?
    assert_includes second_repost.errors[:repost_of], "cannot be a repost of another repost"
  end

  # === Scopes ===

  test "recent scope orders by created_at desc" do
    @note.save!

    newer = Note.create!(
      site: @site,
      user: @user,
      body: "Newer note"
    )

    results = Note.recent.limit(2)
    assert_equal newer, results.first
  end

  test "published scope returns only published notes" do
    @note.save!  # Not published

    published = Note.create!(
      site: @site,
      user: @user,
      body: "Published note",
      published_at: Time.current
    )

    results = Note.published
    assert_includes results, published
    assert_not_includes results, @note
  end

  test "drafts scope returns only unpublished notes" do
    @note.save!  # Draft

    published = Note.create!(
      site: @site,
      user: @user,
      body: "Published note",
      published_at: Time.current
    )

    results = Note.drafts
    assert_includes results, @note
    assert_not_includes results, published
  end

  test "not_hidden scope excludes hidden notes" do
    @note.save!

    hidden = Note.create!(
      site: @site,
      user: @user,
      body: "Hidden note",
      hidden_at: Time.current
    )

    results = Note.not_hidden
    assert_includes results, @note
    assert_not_includes results, hidden
  end

  test "original scope excludes reposts" do
    @note.save!

    reposted = Note.create!(
      site: @site,
      user: @user,
      body: "Repost",
      repost_of: @note
    )

    results = Note.original
    assert_includes results, @note
    assert_not_includes results, reposted
  end

  test "by_user scope filters by user" do
    @note.save!

    other_user = User.create!(email: "other-note-author@example.com", password: "password123")
    other_note = Note.create!(
      site: @site,
      user: other_user,
      body: "Other user's note"
    )

    results = Note.by_user(@user)
    assert_includes results, @note
    assert_not_includes results, other_note
  end

  # === URL Extraction ===

  test "extract_first_url returns URL from body" do
    @note.body = "Check out this link https://example.com/page and more text"
    assert_equal "https://example.com/page", @note.extract_first_url
  end

  test "extract_first_url returns nil for body without URL" do
    @note.body = "Just some text without links"
    assert_nil @note.extract_first_url
  end

  test "extract_first_url handles HTTP URLs" do
    @note.body = "Old school http://example.com/page link"
    assert_equal "http://example.com/page", @note.extract_first_url
  end

  test "extract_first_url returns first URL when multiple present" do
    @note.body = "First https://first.com then https://second.com"
    assert_equal "https://first.com", @note.extract_first_url
  end

  # === Link Preview ===

  test "link_preview returns empty hash by default" do
    assert_equal({}, @note.link_preview)
  end

  test "has_link_preview? returns false by default" do
    assert_not @note.has_link_preview?
  end

  test "has_link_preview? returns true when preview has URL" do
    @note.link_preview = { "url" => "https://example.com", "title" => "Example" }
    assert @note.has_link_preview?
  end

  test "has_link_preview? returns false for empty preview" do
    @note.link_preview = {}
    assert_not @note.has_link_preview?
  end

  # === Counter Caches ===

  test "upvotes_count defaults to 0" do
    assert_equal 0, @note.upvotes_count
  end

  test "comments_count defaults to 0" do
    assert_equal 0, @note.comments_count
  end

  test "reposts_count defaults to 0" do
    assert_equal 0, @note.reposts_count
  end

  # === Delegation ===

  test "delegates author methods to user" do
    @note.save!
    # These should not raise errors even if user doesn't have the methods defined
    assert_nothing_raised { @note.author_profile_name }
  end
end
