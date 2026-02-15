# frozen_string_literal: true

require "rails_helper"

RSpec.describe BusinessSubscription, type: :model do
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant) }
  let(:entry) { create(:entry, :directory, tenant: tenant, category: category) }
  let(:user) { create(:user) }

  describe "associations" do
    it { should belong_to(:entry) }
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:tier) }
    it { should validate_presence_of(:status) }

    it "validates tier inclusion" do
      sub = build(:business_subscription, entry: entry, user: user, tier: "invalid")
      expect(sub).not_to be_valid
      expect(sub.errors[:tier]).to be_present
    end

    it "validates status inclusion" do
      sub = build(:business_subscription, entry: entry, user: user, status: "invalid")
      expect(sub).not_to be_valid
      expect(sub.errors[:status]).to be_present
    end

    it "validates uniqueness of stripe_subscription_id" do
      create(:business_subscription, :with_stripe, entry: entry, user: user, stripe_subscription_id: "sub_123")
      entry2 = create(:entry, :directory, tenant: tenant, category: category)
      duplicate = build(:business_subscription, entry: entry2, user: create(:user), stripe_subscription_id: "sub_123")
      expect(duplicate).not_to be_valid
    end

    it "allows nil stripe_subscription_id" do
      create(:business_subscription, entry: entry, user: user, stripe_subscription_id: nil)
      entry2 = create(:entry, :directory, tenant: tenant, category: category)
      another = build(:business_subscription, entry: entry2, user: create(:user), stripe_subscription_id: nil)
      expect(another).to be_valid
    end
  end

  describe "factory" do
    it "creates a valid business subscription" do
      sub = build(:business_subscription, entry: entry, user: user)
      expect(sub).to be_valid
    end
  end

  describe "scopes" do
    let!(:active_sub) { create(:business_subscription, entry: entry, user: user) }
    let(:entry2) { create(:entry, :directory, tenant: tenant, category: category) }
    let!(:cancelled_sub) { create(:business_subscription, :cancelled, entry: entry2, user: create(:user)) }

    it ".active returns active subscriptions" do
      expect(BusinessSubscription.active).to include(active_sub)
      expect(BusinessSubscription.active).not_to include(cancelled_sub)
    end

    it ".cancelled returns cancelled subscriptions" do
      expect(BusinessSubscription.cancelled).to include(cancelled_sub)
      expect(BusinessSubscription.cancelled).not_to include(active_sub)
    end
  end

  describe "instance methods" do
    let(:subscription) { create(:business_subscription, entry: entry, user: user) }

    it "#cancel! transitions to cancelled" do
      subscription.cancel!
      expect(subscription.reload.status).to eq("cancelled")
    end

    it "#pro? returns true for pro tier" do
      expect(subscription.pro?).to be true
    end

    it "#premium? returns true for premium tier" do
      subscription.update!(tier: "premium")
      expect(subscription.premium?).to be true
    end

    it "#current_period? returns true when within period" do
      subscription.update!(
        current_period_start: 1.day.ago,
        current_period_end: 1.day.from_now
      )
      expect(subscription.current_period?).to be true
    end
  end
end
