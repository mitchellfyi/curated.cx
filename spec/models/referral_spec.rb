# frozen_string_literal: true

# == Schema Information
#
# Table name: referrals
#
#  id                       :bigint           not null, primary key
#  confirmed_at             :datetime
#  referee_ip_hash          :string
#  rewarded_at              :datetime
#  status                   :integer          default("pending"), not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  referee_subscription_id  :bigint           not null
#  referrer_subscription_id :bigint           not null
#  site_id                  :bigint           not null
#
require "rails_helper"

RSpec.describe Referral, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:referrer_user) { create(:user) }
  let(:referee_user) { create(:user) }
  let(:referrer_subscription) { create(:digest_subscription, user: referrer_user, site: site) }
  let(:referee_subscription) { create(:digest_subscription, user: referee_user, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "associations" do
    it { is_expected.to belong_to(:referrer_subscription).class_name("DigestSubscription") }
    it { is_expected.to belong_to(:referee_subscription).class_name("DigestSubscription") }
    it { is_expected.to belong_to(:site) }
  end

  describe "validations" do
    subject { build(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site) }

    it { is_expected.to validate_presence_of(:status) }

    it "validates uniqueness of referee_subscription_id" do
      create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site)
      another_referrer = create(:user)
      another_referrer_subscription = create(:digest_subscription, user: another_referrer, site: site)

      duplicate = build(:referral, referrer_subscription: another_referrer_subscription, referee_subscription: referee_subscription, site: site)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:referee_subscription_id]).to include("has already been referred")
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, confirmed: 1, rewarded: 2, cancelled: 3) }
  end

  describe "scopes" do
    describe ".for_referrer" do
      it "returns referrals for a specific referrer subscription" do
        referral1 = create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site)

        another_referrer = create(:user)
        another_referrer_subscription = create(:digest_subscription, user: another_referrer, site: site)
        another_referee = create(:user)
        another_referee_subscription = create(:digest_subscription, user: another_referee, site: site)
        referral2 = create(:referral, referrer_subscription: another_referrer_subscription, referee_subscription: another_referee_subscription, site: site)

        expect(described_class.for_referrer(referrer_subscription)).to include(referral1)
        expect(described_class.for_referrer(referrer_subscription)).not_to include(referral2)
      end
    end

    describe ".recent" do
      it "orders by created_at descending" do
        old_referral = create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site, created_at: 2.days.ago)

        new_referee = create(:user)
        new_referee_subscription = create(:digest_subscription, user: new_referee, site: site)
        new_referral = create(:referral, referrer_subscription: referrer_subscription, referee_subscription: new_referee_subscription, site: site, created_at: 1.day.ago)

        expect(described_class.recent.first).to eq(new_referral)
        expect(described_class.recent.last).to eq(old_referral)
      end
    end

    describe "status scopes" do
      let!(:pending_referral) { create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site, status: :pending) }

      it "filters by pending status" do
        expect(described_class.pending).to include(pending_referral)
      end

      it "filters by confirmed status" do
        pending_referral.update!(status: :confirmed, confirmed_at: Time.current)
        expect(described_class.confirmed).to include(pending_referral)
      end

      it "filters by rewarded status" do
        pending_referral.update!(status: :rewarded, confirmed_at: 1.day.ago, rewarded_at: Time.current)
        expect(described_class.rewarded).to include(pending_referral)
      end

      it "filters by cancelled status" do
        pending_referral.update!(status: :cancelled)
        expect(described_class.cancelled).to include(pending_referral)
      end
    end
  end

  describe "#confirm!" do
    let(:referral) { create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site, status: :pending) }

    context "when pending" do
      it "transitions to confirmed" do
        freeze_time do
          expect(referral.confirm!).to be true
          expect(referral.status).to eq("confirmed")
          expect(referral.confirmed_at).to eq(Time.current)
        end
      end
    end

    context "when not pending" do
      it "returns false for confirmed referral" do
        referral.update!(status: :confirmed, confirmed_at: Time.current)
        expect(referral.confirm!).to be false
      end

      it "returns false for rewarded referral" do
        referral.update!(status: :rewarded, confirmed_at: 1.day.ago, rewarded_at: Time.current)
        expect(referral.confirm!).to be false
      end

      it "returns false for cancelled referral" do
        referral.update!(status: :cancelled)
        expect(referral.confirm!).to be false
      end
    end
  end

  describe "#mark_rewarded!" do
    let(:referral) { create(:referral, :confirmed, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site) }

    context "when confirmed" do
      it "transitions to rewarded" do
        freeze_time do
          expect(referral.mark_rewarded!).to be true
          expect(referral.status).to eq("rewarded")
          expect(referral.rewarded_at).to eq(Time.current)
        end
      end
    end

    context "when not confirmed" do
      it "returns false for pending referral" do
        referral.update!(status: :pending, confirmed_at: nil)
        expect(referral.mark_rewarded!).to be false
      end

      it "returns false for rewarded referral" do
        referral.update!(status: :rewarded, rewarded_at: Time.current)
        expect(referral.mark_rewarded!).to be false
      end
    end
  end

  describe "#cancel!" do
    let(:referral) { create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site, status: :pending) }

    context "when pending" do
      it "transitions to cancelled" do
        expect(referral.cancel!).to be true
        expect(referral.status).to eq("cancelled")
      end
    end

    context "when confirmed" do
      it "transitions to cancelled" do
        referral.update!(status: :confirmed, confirmed_at: Time.current)
        expect(referral.cancel!).to be true
        expect(referral.status).to eq("cancelled")
      end
    end

    context "when rewarded" do
      it "returns false" do
        referral.update!(status: :rewarded, confirmed_at: 1.day.ago, rewarded_at: Time.current)
        expect(referral.cancel!).to be false
        expect(referral.status).to eq("rewarded")
      end
    end
  end

  describe "#referrer_user" do
    it "returns the referrer subscription user" do
      referral = create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site)
      expect(referral.referrer_user).to eq(referrer_user)
    end
  end

  describe "#referee_user" do
    it "returns the referee subscription user" do
      referral = create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site)
      expect(referral.referee_user).to eq(referee_user)
    end
  end

  describe "SiteScoped concern" do
    it "includes SiteScoped module" do
      expect(described_class.ancestors).to include(SiteScoped)
    end
  end
end
