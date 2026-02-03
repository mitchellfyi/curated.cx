# frozen_string_literal: true

require "test_helper"

class VoteTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_vote") do |t|
      t.hostname = "vote-test.example.com"
      t.title = "Vote Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "vote-test.example.com"
    end

    @source = Source.find_or_create_by!(
      site: @site,
      tenant: @tenant,
      name: "Test Source",
      kind: :rss
    ) do |s|
      s.feed_url = "https://example.com/feed.xml"
    end

    @user = User.find_or_create_by!(email: "voter@example.com") do |u|
      u.password = "password123"
    end

    Current.tenant = @tenant
    Current.site = @site

    @content_item = ContentItem.find_or_create_by!(
      site: @site,
      source: @source,
      url_canonical: "https://example.com/votable-content"
    ) do |c|
      c.url_raw = "https://example.com/votable-content"
      c.raw_payload = {}
      c.tags = []
    end

    @vote = Vote.new(
      site: @site,
      user: @user,
      votable: @content_item,
      value: 1
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @vote.valid?, @vote.errors.full_messages.join(", ")
  end

  test "should require value" do
    @vote.value = nil
    assert_not @vote.valid?
    assert_includes @vote.errors[:value], "can't be blank"
  end

  test "should require integer value" do
    @vote.value = 1.5
    assert_not @vote.valid?
  end

  test "should prevent duplicate votes from same user" do
    @vote.save!

    duplicate = Vote.new(
      site: @site,
      user: @user,
      votable: @content_item,
      value: 1
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already voted on this content"
  end

  test "should allow votes from different users on same content" do
    @vote.save!

    other_user = User.create!(
      email: "other-voter@example.com",
      password: "password123"
    )

    other_vote = Vote.new(
      site: @site,
      user: other_user,
      votable: @content_item,
      value: 1
    )
    assert other_vote.valid?
  end

  test "should allow same user to vote on different content" do
    @vote.save!

    other_content = ContentItem.create!(
      site: @site,
      source: @source,
      url_raw: "https://example.com/other-content",
      url_canonical: "https://example.com/other-content",
      raw_payload: {},
      tags: []
    )

    other_vote = Vote.new(
      site: @site,
      user: @user,
      votable: other_content,
      value: 1
    )
    assert other_vote.valid?
  end

  # === Default Value ===

  test "should default value to 1" do
    vote = Vote.new
    assert_equal 1, vote.value
  end

  # === Polymorphic Votable ===

  test "can vote on content items" do
    @vote.save!
    assert_equal @content_item, @vote.votable
    assert_equal "ContentItem", @vote.votable_type
  end

  test "can vote on notes" do
    note_author = User.create!(email: "note-voter-author@example.com", password: "password123")
    note = Note.create!(
      site: @site,
      user: note_author,
      body: "Votable note"
    )

    vote = Vote.create!(
      site: @site,
      user: @user,
      votable: note,
      value: 1
    )

    assert_equal note, vote.votable
    assert_equal "Note", vote.votable_type
  end

  # === Scopes ===

  test "for_content_item scope filters by specific item" do
    @vote.save!

    other_content = ContentItem.create!(
      site: @site,
      source: @source,
      url_raw: "https://example.com/other-vote-content",
      url_canonical: "https://example.com/other-vote-content",
      raw_payload: {},
      tags: []
    )

    other_vote = Vote.create!(
      site: @site,
      user: User.create!(email: "other-v@example.com", password: "password123"),
      votable: other_content,
      value: 1
    )

    results = Vote.for_content_item(@content_item)
    assert_includes results, @vote
    assert_not_includes results, other_vote
  end

  test "by_user scope filters by user" do
    @vote.save!

    other_user = User.create!(email: "other-by-user@example.com", password: "password123")
    other_vote = Vote.create!(
      site: @site,
      user: other_user,
      votable: @content_item,
      value: 1
    )

    results = Vote.by_user(@user)
    assert_includes results, @vote
    assert_not_includes results, other_vote
  end

  test "content_items scope filters by type" do
    @vote.save!

    note_author = User.create!(email: "type-note-author@example.com", password: "password123")
    note = Note.create!(
      site: @site,
      user: note_author,
      body: "Note for type test"
    )

    note_vote = Vote.create!(
      site: @site,
      user: User.create!(email: "note-voter-type@example.com", password: "password123"),
      votable: note,
      value: 1
    )

    results = Vote.content_items
    assert_includes results, @vote
    assert_not_includes results, note_vote
  end

  test "notes scope filters by type" do
    @vote.save!

    note_author = User.create!(email: "note-scope-author@example.com", password: "password123")
    note = Note.create!(
      site: @site,
      user: note_author,
      body: "Note for scope test"
    )

    note_vote = Vote.create!(
      site: @site,
      user: User.create!(email: "note-scope-voter@example.com", password: "password123"),
      votable: note,
      value: 1
    )

    results = Vote.notes
    assert_not_includes results, @vote
    assert_includes results, note_vote
  end

  # === Counter Cache ===

  test "creates vote and updates counter cache" do
    initial_count = @content_item.upvotes_count

    @vote.save!
    @content_item.reload

    assert_equal initial_count + 1, @content_item.upvotes_count
  end

  test "destroys vote and updates counter cache" do
    @vote.save!
    @content_item.reload
    count_after_vote = @content_item.upvotes_count

    @vote.destroy
    @content_item.reload

    assert_equal count_after_vote - 1, @content_item.upvotes_count
  end
end
