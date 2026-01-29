# frozen_string_literal: true

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
end
