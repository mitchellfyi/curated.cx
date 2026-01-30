# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReferralRewardService do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:referrer_user) { create(:user) }
  let(:subscription) { create(:digest_subscription, user: referrer_user, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  def create_confirmed_referral(subscription)
    referee = create(:user)
    referee_sub = create(:digest_subscription, user: referee, site: site)
    create(:referral, :confirmed, referrer_subscription: subscription, referee_subscription: referee_sub, site: site)
  end

  def create_rewarded_referral(subscription)
    referee = create(:user)
    referee_sub = create(:digest_subscription, user: referee, site: site)
    create(:referral, :rewarded, referrer_subscription: subscription, referee_subscription: referee_sub, site: site)
  end

  describe "#check_and_award!" do
    subject(:service) { described_class.new(subscription) }

    context "when subscription is nil" do
      subject(:service) { described_class.new(nil) }

      it "returns empty array" do
        expect(service.check_and_award!).to eq([])
      end
    end

    context "when no reward tiers exist" do
      before do
        3.times { create_confirmed_referral(subscription) }
      end

      it "returns empty array" do
        expect(service.check_and_award!).to eq([])
      end
    end

    context "when milestone is reached" do
      let!(:tier1) { create(:referral_reward_tier, :first_referral, :digital_download, site: site, milestone: 1) }
      let!(:tier3) { create(:referral_reward_tier, :three_referrals, :featured_mention, site: site, milestone: 3) }

      before do
        3.times { create_confirmed_referral(subscription) }
      end

      it "returns newly earned tiers" do
        result = service.check_and_award!

        expect(result).to include(tier1)
        expect(result).to include(tier3)
      end

      it "marks referrals as rewarded" do
        service.check_and_award!

        rewarded_count = subscription.referrals_as_referrer.rewarded.count
        expect(rewarded_count).to eq(3)
      end

      it "sends reward email for each tier" do
        expect {
          service.check_and_award!
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob).twice
      end
    end

    context "when already rewarded for a milestone" do
      let!(:tier1) { create(:referral_reward_tier, :first_referral, site: site, milestone: 1) }

      before do
        # Create 1 rewarded referral (already received tier1 reward)
        create_rewarded_referral(subscription)
        # Create 1 new confirmed referral
        create_confirmed_referral(subscription)
      end

      it "does not re-award the same tier" do
        result = service.check_and_award!

        expect(result).not_to include(tier1)
      end
    end

    context "when milestone not yet reached" do
      let!(:tier5) { create(:referral_reward_tier, site: site, milestone: 5) }

      before do
        2.times { create_confirmed_referral(subscription) }
      end

      it "returns empty array" do
        expect(service.check_and_award!).to eq([])
      end

      it "does not mark referrals as rewarded" do
        service.check_and_award!

        rewarded_count = subscription.referrals_as_referrer.rewarded.count
        expect(rewarded_count).to eq(0)
      end
    end

    context "with inactive tiers" do
      let!(:active_tier) { create(:referral_reward_tier, site: site, milestone: 1, active: true) }
      let!(:inactive_tier) { create(:referral_reward_tier, site: site, milestone: 2, active: false) }

      before do
        2.times { create_confirmed_referral(subscription) }
      end

      it "only awards active tiers" do
        result = service.check_and_award!

        expect(result).to include(active_tier)
        expect(result).not_to include(inactive_tier)
      end
    end
  end

  describe "#earned_rewards" do
    subject(:service) { described_class.new(subscription) }

    context "when subscription is nil" do
      subject(:service) { described_class.new(nil) }

      it "returns empty array" do
        expect(service.earned_rewards).to eq([])
      end
    end

    context "when no referrals" do
      let!(:tier1) { create(:referral_reward_tier, site: site, milestone: 1) }

      it "returns empty array" do
        expect(service.earned_rewards).to eq([])
      end
    end

    context "when milestones reached" do
      let!(:tier1) { create(:referral_reward_tier, site: site, milestone: 1) }
      let!(:tier3) { create(:referral_reward_tier, site: site, milestone: 3) }
      let!(:tier5) { create(:referral_reward_tier, site: site, milestone: 5) }

      before do
        3.times { create_confirmed_referral(subscription) }
      end

      it "returns tiers up to current count" do
        earned = service.earned_rewards

        expect(earned).to include(tier1)
        expect(earned).to include(tier3)
        expect(earned).not_to include(tier5)
      end
    end

    context "with inactive tiers" do
      let!(:active_tier) { create(:referral_reward_tier, site: site, milestone: 1, active: true) }
      let!(:inactive_tier) { create(:referral_reward_tier, site: site, milestone: 2, active: false) }

      before do
        2.times { create_confirmed_referral(subscription) }
      end

      it "only includes active tiers" do
        earned = service.earned_rewards

        expect(earned).to include(active_tier)
        expect(earned).not_to include(inactive_tier)
      end
    end
  end

  describe "#next_reward" do
    subject(:service) { described_class.new(subscription) }

    context "when subscription is nil" do
      subject(:service) { described_class.new(nil) }

      it "returns nil" do
        expect(service.next_reward).to be_nil
      end
    end

    context "when no tiers exist" do
      it "returns nil" do
        expect(service.next_reward).to be_nil
      end
    end

    context "when next tier exists" do
      let!(:tier1) { create(:referral_reward_tier, site: site, milestone: 1) }
      let!(:tier3) { create(:referral_reward_tier, site: site, milestone: 3) }

      it "returns next tier when no referrals" do
        expect(service.next_reward).to eq(tier1)
      end

      it "returns next unearned tier" do
        create_confirmed_referral(subscription)
        expect(service.next_reward).to eq(tier3)
      end
    end

    context "when all tiers earned" do
      let!(:tier1) { create(:referral_reward_tier, site: site, milestone: 1) }

      before do
        2.times { create_confirmed_referral(subscription) }
      end

      it "returns nil" do
        expect(service.next_reward).to be_nil
      end
    end
  end

  describe "#progress" do
    subject(:service) { described_class.new(subscription) }

    context "when subscription is nil" do
      subject(:service) { described_class.new(nil) }

      it "returns progress with zero count" do
        progress = service.progress

        expect(progress[:confirmed_count]).to eq(0)
        expect(progress[:next_milestone]).to be_nil
        expect(progress[:referrals_needed]).to be_nil
        expect(progress[:next_reward_name]).to be_nil
      end
    end

    context "when no tiers exist" do
      before do
        2.times { create_confirmed_referral(subscription) }
      end

      it "returns progress without next milestone" do
        progress = service.progress

        expect(progress[:confirmed_count]).to eq(2)
        expect(progress[:next_milestone]).to be_nil
        expect(progress[:referrals_needed]).to be_nil
      end
    end

    context "when working towards next tier" do
      let!(:tier5) { create(:referral_reward_tier, site: site, milestone: 5, name: "Five Referrals Bonus") }

      before do
        2.times { create_confirmed_referral(subscription) }
      end

      it "returns complete progress info" do
        progress = service.progress

        expect(progress[:confirmed_count]).to eq(2)
        expect(progress[:next_milestone]).to eq(5)
        expect(progress[:referrals_needed]).to eq(3)
        expect(progress[:next_reward_name]).to eq("Five Referrals Bonus")
      end
    end

    context "with mixed confirmed and rewarded referrals" do
      let!(:tier5) { create(:referral_reward_tier, site: site, milestone: 5) }

      before do
        2.times { create_confirmed_referral(subscription) }
        1.times { create_rewarded_referral(subscription) }
      end

      it "counts both as confirmed" do
        progress = service.progress

        expect(progress[:confirmed_count]).to eq(3)
        expect(progress[:referrals_needed]).to eq(2)
      end
    end
  end
end
