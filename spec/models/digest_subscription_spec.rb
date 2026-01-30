# frozen_string_literal: true

# == Schema Information
#
# Table name: digest_subscriptions
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE), not null
#  frequency         :integer          default("weekly"), not null
#  last_sent_at      :datetime
#  preferences       :jsonb            not null
#  referral_code     :string           not null
#  unsubscribe_token :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  site_id           :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_digest_subscriptions_on_referral_code                     (referral_code) UNIQUE
#  index_digest_subscriptions_on_site_id                           (site_id)
#  index_digest_subscriptions_on_site_id_and_frequency_and_active  (site_id,frequency,active)
#  index_digest_subscriptions_on_unsubscribe_token                 (unsubscribe_token) UNIQUE
#  index_digest_subscriptions_on_user_id                           (user_id)
#  index_digest_subscriptions_on_user_id_and_site_id               (user_id,site_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (user_id => users.id)
#
require "rails_helper"

RSpec.describe DigestSubscription, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "validations" do
    it "validates uniqueness of user per site" do
      create(:digest_subscription, user: user, site: site)
      duplicate = build(:digest_subscription, user: user, site: site)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("already subscribed to this site")
    end

    it "validates presence of unsubscribe_token" do
      subscription = build(:digest_subscription, unsubscribe_token: nil)
      subscription.valid?
      expect(subscription.unsubscribe_token).to be_present
    end
  end

  describe "callbacks" do
    it "generates unsubscribe_token on create" do
      subscription = build(:digest_subscription, user: user, site: site, unsubscribe_token: nil)
      subscription.save!

      expect(subscription.unsubscribe_token).to be_present
      expect(subscription.unsubscribe_token.length).to be >= 32
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active subscriptions" do
        active = create(:digest_subscription, user: user, site: site, active: true)
        other_user = create(:user)
        inactive = create(:digest_subscription, user: other_user, site: site, active: false)

        expect(described_class.active).to include(active)
        expect(described_class.active).not_to include(inactive)
      end
    end

    describe ".due_for_weekly" do
      it "returns weekly subscriptions due for sending" do
        due = create(:digest_subscription, :due, user: user, site: site, frequency: :weekly)
        other_user = create(:user)
        not_due = create(:digest_subscription, :recently_sent, user: other_user, site: site, frequency: :weekly)

        expect(described_class.due_for_weekly).to include(due)
        expect(described_class.due_for_weekly).not_to include(not_due)
      end

      it "includes subscriptions never sent" do
        never_sent = create(:digest_subscription, user: user, site: site, frequency: :weekly, last_sent_at: nil)

        expect(described_class.due_for_weekly).to include(never_sent)
      end
    end

    describe ".due_for_daily" do
      it "returns daily subscriptions due for sending" do
        due = create(:digest_subscription, user: user, site: site, frequency: :daily, last_sent_at: 2.days.ago)
        other_user = create(:user)
        not_due = create(:digest_subscription, :recently_sent, user: other_user, site: site, frequency: :daily)

        expect(described_class.due_for_daily).to include(due)
        expect(described_class.due_for_daily).not_to include(not_due)
      end
    end
  end

  describe "#mark_sent!" do
    it "updates last_sent_at" do
      subscription = create(:digest_subscription, user: user, site: site, last_sent_at: nil)

      freeze_time do
        subscription.mark_sent!
        expect(subscription.last_sent_at).to eq(Time.current)
      end
    end
  end

  describe "#unsubscribe!" do
    it "sets active to false" do
      subscription = create(:digest_subscription, user: user, site: site, active: true)

      subscription.unsubscribe!

      expect(subscription.active).to be false
    end
  end

  describe "#resubscribe!" do
    it "sets active to true" do
      subscription = create(:digest_subscription, :inactive, user: user, site: site)

      subscription.resubscribe!

      expect(subscription.active).to be true
    end
  end

  describe "referral_code" do
    describe "generation" do
      it "generates referral_code on create" do
        subscription = build(:digest_subscription, user: user, site: site, referral_code: nil)
        subscription.save!

        expect(subscription.referral_code).to be_present
        expect(subscription.referral_code.length).to be >= 8
      end

      it "does not overwrite existing referral_code" do
        subscription = build(:digest_subscription, user: user, site: site, referral_code: "existing123")
        subscription.save!

        expect(subscription.referral_code).to eq("existing123")
      end

      it "validates uniqueness of referral_code" do
        subscription1 = create(:digest_subscription, user: user, site: site)
        other_user = create(:user)
        subscription2 = build(:digest_subscription, user: other_user, site: site, referral_code: subscription1.referral_code)

        expect(subscription2).not_to be_valid
        expect(subscription2.errors[:referral_code]).to include("has already been taken")
      end
    end

    describe "#referral_link" do
      let(:subscription) { create(:digest_subscription, user: user, site: site) }

      it "returns a properly formatted referral URL" do
        allow(site).to receive(:primary_hostname).and_return("example.com")

        expect(subscription.referral_link).to eq("https://example.com/subscribe?ref=#{subscription.referral_code}")
      end

      it "uses curated.cx as fallback hostname" do
        allow(site).to receive(:primary_hostname).and_return(nil)

        expect(subscription.referral_link).to eq("https://curated.cx/subscribe?ref=#{subscription.referral_code}")
      end
    end

    describe "#confirmed_referrals_count" do
      let(:subscription) { create(:digest_subscription, user: user, site: site) }

      it "returns 0 when no referrals" do
        expect(subscription.confirmed_referrals_count).to eq(0)
      end

      it "counts confirmed referrals" do
        referee1 = create(:user)
        referee1_sub = create(:digest_subscription, user: referee1, site: site)
        create(:referral, :confirmed, referrer_subscription: subscription, referee_subscription: referee1_sub, site: site)

        expect(subscription.confirmed_referrals_count).to eq(1)
      end

      it "counts rewarded referrals" do
        referee1 = create(:user)
        referee1_sub = create(:digest_subscription, user: referee1, site: site)
        create(:referral, :rewarded, referrer_subscription: subscription, referee_subscription: referee1_sub, site: site)

        expect(subscription.confirmed_referrals_count).to eq(1)
      end

      it "does not count pending referrals" do
        referee1 = create(:user)
        referee1_sub = create(:digest_subscription, user: referee1, site: site)
        create(:referral, referrer_subscription: subscription, referee_subscription: referee1_sub, site: site, status: :pending)

        expect(subscription.confirmed_referrals_count).to eq(0)
      end

      it "does not count cancelled referrals" do
        referee1 = create(:user)
        referee1_sub = create(:digest_subscription, user: referee1, site: site)
        create(:referral, :cancelled, referrer_subscription: subscription, referee_subscription: referee1_sub, site: site)

        expect(subscription.confirmed_referrals_count).to eq(0)
      end
    end
  end

  describe "referral associations" do
    let(:subscription) { create(:digest_subscription, user: user, site: site) }

    describe "referrals_as_referrer" do
      it "returns referrals where this subscription is the referrer" do
        referee = create(:user)
        referee_sub = create(:digest_subscription, user: referee, site: site)
        referral = create(:referral, referrer_subscription: subscription, referee_subscription: referee_sub, site: site)

        expect(subscription.referrals_as_referrer).to include(referral)
      end
    end

    describe "referral_as_referee" do
      it "returns the referral where this subscription is the referee" do
        referrer = create(:user)
        referrer_sub = create(:digest_subscription, user: referrer, site: site)
        referral = create(:referral, referrer_subscription: referrer_sub, referee_subscription: subscription, site: site)

        expect(subscription.referral_as_referee).to eq(referral)
      end
    end
  end
end
