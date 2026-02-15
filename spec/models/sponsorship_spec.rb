# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sponsorship, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }

  before { Current.site = site }
  after { Current.site = nil }

  describe "associations" do
    it { should belong_to(:entry).optional }
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:placement_type) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:starts_at) }
    it { should validate_presence_of(:ends_at) }
    it { should validate_numericality_of(:budget_cents).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:spent_cents).is_greater_than_or_equal_to(0) }

    it "validates placement_type inclusion" do
      sponsorship = build(:sponsorship, site: site, user: user, placement_type: "invalid")
      expect(sponsorship).not_to be_valid
      expect(sponsorship.errors[:placement_type]).to be_present
    end

    it "validates status inclusion" do
      sponsorship = build(:sponsorship, site: site, user: user, status: "invalid")
      expect(sponsorship).not_to be_valid
      expect(sponsorship.errors[:status]).to be_present
    end

    it "validates ends_at is after starts_at" do
      sponsorship = build(:sponsorship, site: site, user: user, starts_at: 1.day.from_now, ends_at: 1.day.ago)
      expect(sponsorship).not_to be_valid
      expect(sponsorship.errors[:ends_at]).to be_present
    end
  end

  describe "factory" do
    it "creates a valid sponsorship" do
      sponsorship = build(:sponsorship, site: site, user: user)
      expect(sponsorship).to be_valid
    end
  end

  describe "scopes" do
    let!(:active) { create(:sponsorship, :active, site: site, user: user) }
    let!(:pending) { create(:sponsorship, site: site, user: user) }
    let!(:paused) { create(:sponsorship, :paused, site: site, user: user) }

    it ".active returns only active sponsorships" do
      expect(Sponsorship.active).to include(active)
      expect(Sponsorship.active).not_to include(pending)
    end

    it ".pending returns only pending sponsorships" do
      expect(Sponsorship.pending).to include(pending)
      expect(Sponsorship.pending).not_to include(active)
    end
  end

  describe "instance methods" do
    let(:sponsorship) { create(:sponsorship, :active, :with_performance, site: site, user: user, budget_cents: 10_000) }

    it "#ctr calculates click-through rate" do
      expect(sponsorship.ctr).to eq(5.0) # 50/1000 * 100
    end

    it "#budget_remaining_cents returns remaining budget" do
      expect(sponsorship.budget_remaining_cents).to eq(5000) # 10000 - 5000
    end

    it "#budget_exhausted? returns true when budget is spent" do
      sponsorship.update_columns(spent_cents: 10_000)
      expect(sponsorship.budget_exhausted?).to be true
    end

    it "#approve! transitions to active" do
      pending_sponsorship = create(:sponsorship, site: site, user: user)
      pending_sponsorship.approve!
      expect(pending_sponsorship.reload.status).to eq("active")
    end

    it "#pause! transitions to paused" do
      sponsorship.pause!
      expect(sponsorship.reload.status).to eq("paused")
    end

    it "#complete! transitions to completed" do
      sponsorship.complete!
      expect(sponsorship.reload.status).to eq("completed")
    end

    it "#reject! transitions to rejected" do
      pending_sponsorship = create(:sponsorship, site: site, user: user)
      pending_sponsorship.reject!
      expect(pending_sponsorship.reload.status).to eq("rejected")
    end
  end
end
