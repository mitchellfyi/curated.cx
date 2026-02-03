# frozen_string_literal: true

require "test_helper"

class DigestSubscriptionTest < ActiveSupport::TestCase
  def setup
    @tenant = Tenant.find_or_create_by!(slug: "test_digest") do |t|
      t.hostname = "digest-test.example.com"
      t.title = "Digest Test Tenant"
    end

    @site = Site.find_or_create_by!(tenant: @tenant, name: "Test Site") do |s|
      s.primary_hostname = "digest-test.example.com"
    end

    @user = User.find_or_create_by!(email: "subscriber@example.com") do |u|
      u.password = "password123"
    end

    Current.tenant = @tenant
    Current.site = @site

    @subscription = DigestSubscription.new(
      site: @site,
      user: @user,
      frequency: :weekly
    )
  end

  def teardown
    Current.tenant = nil
    Current.site = nil
  end

  # === Validations ===

  test "should be valid with valid attributes" do
    assert @subscription.valid?, @subscription.errors.full_messages.join(", ")
  end

  test "should require unique user per site" do
    @subscription.save!

    duplicate = DigestSubscription.new(
      site: @site,
      user: @user,
      frequency: :daily
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "already subscribed to this site"
  end

  test "should allow same user on different sites" do
    @subscription.save!

    other_site = Site.create!(
      tenant: @tenant,
      name: "Other Site",
      slug: "other_digest_site"
    )

    other_subscription = DigestSubscription.new(
      site: other_site,
      user: @user,
      frequency: :weekly
    )

    Current.site = other_site
    assert other_subscription.valid?, other_subscription.errors.full_messages.join(", ")
  end

  # === Auto-generated Tokens ===

  test "generates unsubscribe_token on create" do
    @subscription.save!
    assert_not_nil @subscription.unsubscribe_token
    assert @subscription.unsubscribe_token.length > 10
  end

  test "generates unique unsubscribe_token" do
    @subscription.save!

    other_user = User.create!(email: "other-sub@example.com", password: "password123")
    other = DigestSubscription.create!(
      site: @site,
      user: other_user,
      frequency: :weekly
    )

    assert_not_equal @subscription.unsubscribe_token, other.unsubscribe_token
  end

  test "generates referral_code on create" do
    @subscription.save!
    assert_not_nil @subscription.referral_code
    assert @subscription.referral_code.length > 5
  end

  test "generates unique referral_code" do
    @subscription.save!

    other_user = User.create!(email: "other-ref@example.com", password: "password123")
    other = DigestSubscription.create!(
      site: @site,
      user: other_user,
      frequency: :weekly
    )

    assert_not_equal @subscription.referral_code, other.referral_code
  end

  # === Frequency Enum ===

  test "should default to weekly frequency" do
    subscription = DigestSubscription.new
    assert_equal "weekly", subscription.frequency
  end

  test "should have weekly frequency" do
    @subscription.frequency = :weekly
    assert @subscription.weekly?
  end

  test "should have daily frequency" do
    @subscription.frequency = :daily
    assert @subscription.daily?
  end

  # === Active Status ===

  test "should be active by default" do
    subscription = DigestSubscription.new
    assert subscription.active?
  end

  test "unsubscribe! sets active to false" do
    @subscription.save!
    @subscription.unsubscribe!

    assert_not @subscription.active?
  end

  test "resubscribe! sets active to true" do
    @subscription.save!
    @subscription.update!(active: false)
    @subscription.resubscribe!

    assert @subscription.active?
  end

  # === Scopes ===

  test "active scope returns only active subscriptions" do
    @subscription.save!

    inactive = DigestSubscription.create!(
      site: @site,
      user: User.create!(email: "inactive@example.com", password: "password123"),
      frequency: :weekly,
      active: false
    )

    results = DigestSubscription.active
    assert_includes results, @subscription
    assert_not_includes results, inactive
  end

  test "due_for_weekly scope returns subscriptions needing weekly digest" do
    @subscription.frequency = :weekly
    @subscription.last_sent_at = nil
    @subscription.save!

    recently_sent = DigestSubscription.create!(
      site: @site,
      user: User.create!(email: "recent@example.com", password: "password123"),
      frequency: :weekly,
      last_sent_at: 1.day.ago
    )

    results = DigestSubscription.due_for_weekly
    assert_includes results, @subscription
    assert_not_includes results, recently_sent
  end

  test "due_for_weekly returns subscriptions sent over a week ago" do
    @subscription.frequency = :weekly
    @subscription.last_sent_at = 8.days.ago
    @subscription.save!

    results = DigestSubscription.due_for_weekly
    assert_includes results, @subscription
  end

  test "due_for_daily scope returns subscriptions needing daily digest" do
    @subscription.frequency = :daily
    @subscription.last_sent_at = nil
    @subscription.save!

    recently_sent = DigestSubscription.create!(
      site: @site,
      user: User.create!(email: "recent-daily@example.com", password: "password123"),
      frequency: :daily,
      last_sent_at: 1.hour.ago
    )

    results = DigestSubscription.due_for_daily
    assert_includes results, @subscription
    assert_not_includes results, recently_sent
  end

  # === Mark Sent ===

  test "mark_sent! updates last_sent_at" do
    @subscription.save!
    @subscription.mark_sent!

    assert_not_nil @subscription.last_sent_at
    assert @subscription.last_sent_at > 1.minute.ago
  end

  # === Preferences ===

  test "preferences returns empty hash by default" do
    subscription = DigestSubscription.new
    assert_equal({}, subscription.preferences)
  end

  test "preferences can store values" do
    @subscription.preferences = { "topics" => [ "ai", "tools" ], "include_jobs" => true }
    @subscription.save!
    @subscription.reload

    assert_equal [ "ai", "tools" ], @subscription.preferences["topics"]
    assert_equal true, @subscription.preferences["include_jobs"]
  end

  # === Referral Link ===

  test "referral_link generates correct URL" do
    @subscription.save!
    link = @subscription.referral_link

    assert_includes link, "https://digest-test.example.com/subscribe"
    assert_includes link, "ref=#{@subscription.referral_code}"
  end

  # === Confirmed Referrals Count ===

  test "confirmed_referrals_count returns 0 with no referrals" do
    @subscription.save!
    assert_equal 0, @subscription.confirmed_referrals_count
  end

  # === Associations ===

  test "belongs to user" do
    @subscription.save!
    assert_equal @user, @subscription.user
  end

  test "belongs to site" do
    @subscription.save!
    assert_equal @site, @subscription.site
  end

  test "has many subscriber_tags through subscriber_taggings" do
    @subscription.save!

    tag = SubscriberTag.create!(
      site: @site,
      tenant: @tenant,
      name: "VIP"
    )

    @subscription.subscriber_tags << tag

    assert_includes @subscription.subscriber_tags, tag
  end
end
