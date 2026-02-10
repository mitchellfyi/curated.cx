# frozen_string_literal: true

require "rails_helper"

RSpec.describe SegmentationService, type: :service do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe ".subscribers_for" do
    it "delegates to instance subscribers" do
      segment = create(:subscriber_segment, site: site, rules: {})
      expect_any_instance_of(described_class).to receive(:subscribers).and_call_original
      described_class.subscribers_for(segment)
    end
  end

  describe "#subscribers" do
    context "with empty rules" do
      it "returns all subscribers for the site" do
        segment = create(:subscriber_segment, site: site, rules: {})
        user1 = create(:user)
        user2 = create(:user)
        sub1 = create(:digest_subscription, user: user1, site: site)
        sub2 = create(:digest_subscription, user: user2, site: site)

        result = described_class.subscribers_for(segment)

        expect(result).to include(sub1, sub2)
        expect(result.count).to eq(2)
      end

      it "does not include subscribers from other sites" do
        segment = create(:subscriber_segment, site: site, rules: {})
        other_site = create(:site, tenant: tenant)
        user1 = create(:user)
        user2 = create(:user)
        sub1 = create(:digest_subscription, user: user1, site: site)
        other_sub = create(:digest_subscription, user: user2, site: other_site)

        result = described_class.subscribers_for(segment)

        expect(result).to include(sub1)
        expect(result).not_to include(other_sub)
      end
    end

    context "with subscription_age rule" do
      it "filters by min_days (subscribed at least N days ago)" do
        segment = create(:subscriber_segment, site: site, rules: {
          "subscription_age" => { "min_days" => 7 }
        })
        user_old = create(:user)
        user_new = create(:user)
        old_sub = create(:digest_subscription, user: user_old, site: site, created_at: 10.days.ago)
        new_sub = create(:digest_subscription, user: user_new, site: site, created_at: 3.days.ago)

        result = described_class.subscribers_for(segment)

        expect(result).to include(old_sub)
        expect(result).not_to include(new_sub)
      end

      it "filters by max_days (subscribed within the last N days)" do
        segment = create(:subscriber_segment, site: site, rules: {
          "subscription_age" => { "max_days" => 7 }
        })
        user_old = create(:user)
        user_new = create(:user)
        old_sub = create(:digest_subscription, user: user_old, site: site, created_at: 10.days.ago)
        new_sub = create(:digest_subscription, user: user_new, site: site, created_at: 3.days.ago)

        result = described_class.subscribers_for(segment)

        expect(result).to include(new_sub)
        expect(result).not_to include(old_sub)
      end

      it "filters by both min_days and max_days" do
        segment = create(:subscriber_segment, site: site, rules: {
          "subscription_age" => { "min_days" => 3, "max_days" => 10 }
        })
        user_very_old = create(:user)
        user_in_range = create(:user)
        user_very_new = create(:user)
        very_old_sub = create(:digest_subscription, user: user_very_old, site: site, created_at: 15.days.ago)
        in_range_sub = create(:digest_subscription, user: user_in_range, site: site, created_at: 5.days.ago)
        very_new_sub = create(:digest_subscription, user: user_very_new, site: site, created_at: 1.day.ago)

        result = described_class.subscribers_for(segment)

        expect(result).to include(in_range_sub)
        expect(result).not_to include(very_old_sub)
        expect(result).not_to include(very_new_sub)
      end
    end

    context "with engagement_level rule" do
      it "filters by minimum actions within time window" do
        segment = create(:subscriber_segment, site: site, rules: {
          "engagement_level" => { "min_actions" => 2, "within_days" => 30 }
        })
        engaged_user = create(:user)
        inactive_user = create(:user)
        engaged_sub = create(:digest_subscription, user: engaged_user, site: site)
        inactive_sub = create(:digest_subscription, user: inactive_user, site: site)

        # Create engagement for the engaged user (votes on different content items)
        content1 = create(:entry, :feed, source: source)
        content2 = create(:entry, :feed, source: source)
        create(:vote, user: engaged_user, entry: content1, site: site, created_at: 5.days.ago)
        create(:vote, user: engaged_user, entry: content2, site: site, created_at: 10.days.ago)

        result = described_class.subscribers_for(segment)

        expect(result).to include(engaged_sub)
        expect(result).not_to include(inactive_sub)
      end

      it "excludes old engagement outside the time window" do
        segment = create(:subscriber_segment, site: site, rules: {
          "engagement_level" => { "min_actions" => 2, "within_days" => 30 }
        })
        user = create(:user)
        sub = create(:digest_subscription, user: user, site: site)

        # Create engagement outside the time window (votes on different content items)
        content1 = create(:entry, :feed, source: source)
        content2 = create(:entry, :feed, source: source)
        create(:vote, user: user, entry: content1, site: site, created_at: 35.days.ago)
        create(:vote, user: user, entry: content2, site: site, created_at: 40.days.ago)

        result = described_class.subscribers_for(segment)

        expect(result).not_to include(sub)
      end

      it "counts bookmarks as engagement" do
        segment = create(:subscriber_segment, site: site, rules: {
          "engagement_level" => { "min_actions" => 1, "within_days" => 30 }
        })
        user = create(:user)
        sub = create(:digest_subscription, user: user, site: site)

        # Create a bookmark
        content = create(:entry, :feed, source: source)
        create(:bookmark, user: user, bookmarkable: content, created_at: 5.days.ago)

        result = described_class.subscribers_for(segment)

        expect(result).to include(sub)
      end

      it "counts content_views as engagement" do
        segment = create(:subscriber_segment, site: site, rules: {
          "engagement_level" => { "min_actions" => 1, "within_days" => 30 }
        })
        user = create(:user)
        sub = create(:digest_subscription, user: user, site: site)

        # Create a content view
        content = create(:entry, :feed, source: source)
        create(:content_view, user: user, entry: content, site: site, created_at: 5.days.ago)

        result = described_class.subscribers_for(segment)

        expect(result).to include(sub)
      end

      it "combines votes, bookmarks, and content_views for total count" do
        segment = create(:subscriber_segment, site: site, rules: {
          "engagement_level" => { "min_actions" => 3, "within_days" => 30 }
        })
        user = create(:user)
        sub = create(:digest_subscription, user: user, site: site)

        content = create(:entry, :feed, source: source)
        create(:vote, user: user, entry: content, site: site, created_at: 5.days.ago)
        create(:bookmark, user: user, bookmarkable: content, created_at: 5.days.ago)
        create(:content_view, user: user, entry: content, site: site, created_at: 5.days.ago)

        result = described_class.subscribers_for(segment)

        expect(result).to include(sub)
      end
    end

    context "with referral_count rule" do
      it "filters by minimum confirmed referrals" do
        segment = create(:subscriber_segment, site: site, rules: {
          "referral_count" => { "min" => 3 }
        })
        power_user = create(:user)
        regular_user = create(:user)
        power_sub = create(:digest_subscription, user: power_user, site: site)
        regular_sub = create(:digest_subscription, user: regular_user, site: site)

        # Create 3 confirmed referrals for power_user
        3.times do
          referee = create(:user)
          referee_sub = create(:digest_subscription, user: referee, site: site)
          create(:referral, :confirmed, referrer_subscription: power_sub, referee_subscription: referee_sub, site: site)
        end

        # Create 1 confirmed referral for regular_user
        referee = create(:user)
        referee_sub = create(:digest_subscription, user: referee, site: site)
        create(:referral, :confirmed, referrer_subscription: regular_sub, referee_subscription: referee_sub, site: site)

        result = described_class.subscribers_for(segment)

        expect(result).to include(power_sub)
        expect(result).not_to include(regular_sub)
      end

      it "counts rewarded referrals" do
        segment = create(:subscriber_segment, site: site, rules: {
          "referral_count" => { "min" => 1 }
        })
        user = create(:user)
        sub = create(:digest_subscription, user: user, site: site)

        referee = create(:user)
        referee_sub = create(:digest_subscription, user: referee, site: site)
        create(:referral, :rewarded, referrer_subscription: sub, referee_subscription: referee_sub, site: site)

        result = described_class.subscribers_for(segment)

        expect(result).to include(sub)
      end

      it "does not count pending referrals" do
        segment = create(:subscriber_segment, site: site, rules: {
          "referral_count" => { "min" => 1 }
        })
        user = create(:user)
        sub = create(:digest_subscription, user: user, site: site)

        referee = create(:user)
        referee_sub = create(:digest_subscription, user: referee, site: site)
        create(:referral, referrer_subscription: sub, referee_subscription: referee_sub, site: site, status: :pending)

        result = described_class.subscribers_for(segment)

        expect(result).not_to include(sub)
      end
    end

    context "with tags rule" do
      let!(:vip_tag) { create(:subscriber_tag, site: site, name: "VIP", slug: "vip") }
      let!(:beta_tag) { create(:subscriber_tag, site: site, name: "Beta", slug: "beta") }
      let!(:premium_tag) { create(:subscriber_tag, site: site, name: "Premium", slug: "premium") }

      it "filters by any tags (OR logic)" do
        segment = create(:subscriber_segment, site: site, rules: {
          "tags" => { "any" => %w[vip beta] }
        })
        vip_user = create(:user)
        beta_user = create(:user)
        untagged_user = create(:user)
        vip_sub = create(:digest_subscription, user: vip_user, site: site)
        beta_sub = create(:digest_subscription, user: beta_user, site: site)
        untagged_sub = create(:digest_subscription, user: untagged_user, site: site)

        create(:subscriber_tagging, digest_subscription: vip_sub, subscriber_tag: vip_tag)
        create(:subscriber_tagging, digest_subscription: beta_sub, subscriber_tag: beta_tag)

        result = described_class.subscribers_for(segment)

        expect(result).to include(vip_sub, beta_sub)
        expect(result).not_to include(untagged_sub)
      end

      it "filters by all tags (AND logic)" do
        segment = create(:subscriber_segment, site: site, rules: {
          "tags" => { "all" => %w[vip premium] }
        })
        both_tags_user = create(:user)
        one_tag_user = create(:user)
        both_tags_sub = create(:digest_subscription, user: both_tags_user, site: site)
        one_tag_sub = create(:digest_subscription, user: one_tag_user, site: site)

        create(:subscriber_tagging, digest_subscription: both_tags_sub, subscriber_tag: vip_tag)
        create(:subscriber_tagging, digest_subscription: both_tags_sub, subscriber_tag: premium_tag)
        create(:subscriber_tagging, digest_subscription: one_tag_sub, subscriber_tag: vip_tag)

        result = described_class.subscribers_for(segment)

        expect(result).to include(both_tags_sub)
        expect(result).not_to include(one_tag_sub)
      end

      it "combines any and all tags" do
        segment = create(:subscriber_segment, site: site, rules: {
          "tags" => { "any" => %w[vip beta], "all" => %w[premium] }
        })
        vip_premium_user = create(:user)
        vip_only_user = create(:user)
        vip_premium_sub = create(:digest_subscription, user: vip_premium_user, site: site)
        vip_only_sub = create(:digest_subscription, user: vip_only_user, site: site)

        create(:subscriber_tagging, digest_subscription: vip_premium_sub, subscriber_tag: vip_tag)
        create(:subscriber_tagging, digest_subscription: vip_premium_sub, subscriber_tag: premium_tag)
        create(:subscriber_tagging, digest_subscription: vip_only_sub, subscriber_tag: vip_tag)

        result = described_class.subscribers_for(segment)

        expect(result).to include(vip_premium_sub)
        expect(result).not_to include(vip_only_sub)
      end
    end

    context "with frequency rule" do
      it "filters by weekly frequency" do
        segment = create(:subscriber_segment, site: site, rules: {
          "frequency" => "weekly"
        })
        weekly_user = create(:user)
        daily_user = create(:user)
        weekly_sub = create(:digest_subscription, user: weekly_user, site: site, frequency: :weekly)
        daily_sub = create(:digest_subscription, user: daily_user, site: site, frequency: :daily)

        result = described_class.subscribers_for(segment)

        expect(result).to include(weekly_sub)
        expect(result).not_to include(daily_sub)
      end

      it "filters by daily frequency" do
        segment = create(:subscriber_segment, site: site, rules: {
          "frequency" => "daily"
        })
        weekly_user = create(:user)
        daily_user = create(:user)
        weekly_sub = create(:digest_subscription, user: weekly_user, site: site, frequency: :weekly)
        daily_sub = create(:digest_subscription, user: daily_user, site: site, frequency: :daily)

        result = described_class.subscribers_for(segment)

        expect(result).to include(daily_sub)
        expect(result).not_to include(weekly_sub)
      end
    end

    context "with active rule" do
      it "filters by active true" do
        segment = create(:subscriber_segment, site: site, rules: {
          "active" => true
        })
        active_user = create(:user)
        inactive_user = create(:user)
        active_sub = create(:digest_subscription, user: active_user, site: site, active: true)
        inactive_sub = create(:digest_subscription, user: inactive_user, site: site, active: false)

        result = described_class.subscribers_for(segment)

        expect(result).to include(active_sub)
        expect(result).not_to include(inactive_sub)
      end

      it "filters by active false" do
        segment = create(:subscriber_segment, site: site, rules: {
          "active" => false
        })
        active_user = create(:user)
        inactive_user = create(:user)
        active_sub = create(:digest_subscription, user: active_user, site: site, active: true)
        inactive_sub = create(:digest_subscription, user: inactive_user, site: site, active: false)

        result = described_class.subscribers_for(segment)

        expect(result).to include(inactive_sub)
        expect(result).not_to include(active_sub)
      end
    end

    context "with combined rules (AND logic)" do
      it "applies all rules together" do
        segment = create(:subscriber_segment, site: site, rules: {
          "active" => true,
          "frequency" => "weekly",
          "subscription_age" => { "max_days" => 30 }
        })
        matching_user = create(:user)
        wrong_frequency_user = create(:user)
        too_old_user = create(:user)

        matching_sub = create(:digest_subscription,
          user: matching_user,
          site: site,
          active: true,
          frequency: :weekly,
          created_at: 7.days.ago)

        wrong_freq_sub = create(:digest_subscription,
          user: wrong_frequency_user,
          site: site,
          active: true,
          frequency: :daily,
          created_at: 7.days.ago)

        too_old_sub = create(:digest_subscription,
          user: too_old_user,
          site: site,
          active: true,
          frequency: :weekly,
          created_at: 60.days.ago)

        result = described_class.subscribers_for(segment)

        expect(result).to include(matching_sub)
        expect(result).not_to include(wrong_freq_sub)
        expect(result).not_to include(too_old_sub)
      end
    end

    context "with no matches" do
      it "returns empty relation" do
        segment = create(:subscriber_segment, site: site, rules: {
          "referral_count" => { "min" => 100 }
        })
        user = create(:user)
        create(:digest_subscription, user: user, site: site)

        result = described_class.subscribers_for(segment)

        expect(result).to be_empty
      end
    end
  end
end
