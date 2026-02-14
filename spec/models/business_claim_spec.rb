# frozen_string_literal: true

require "rails_helper"

RSpec.describe BusinessClaim, type: :model do
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant) }
  let(:entry) { create(:entry, :directory, tenant: tenant, category: category) }
  let(:user) { create(:user) }

  describe "associations" do
    it { should belong_to(:entry) }
    it { should belong_to(:user) }
  end

  describe "validations" do
    it { should validate_presence_of(:status) }

    it "validates status inclusion" do
      claim = build(:business_claim, entry: entry, user: user, status: "invalid")
      expect(claim).not_to be_valid
      expect(claim.errors[:status]).to be_present
    end

    it "validates verification_method inclusion when present" do
      claim = build(:business_claim, entry: entry, user: user, verification_method: "invalid")
      expect(claim).not_to be_valid
      expect(claim.errors[:verification_method]).to be_present
    end

    it "allows blank verification_method" do
      claim = build(:business_claim, entry: entry, user: user, verification_method: nil)
      expect(claim).to be_valid
    end

    it "validates uniqueness of entry per user" do
      create(:business_claim, entry: entry, user: user)
      duplicate = build(:business_claim, entry: entry, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:entry_id]).to be_present
    end
  end

  describe "factory" do
    it "creates a valid business claim" do
      claim = build(:business_claim, entry: entry, user: user)
      expect(claim).to be_valid
    end
  end

  describe "scopes" do
    let!(:pending_claim) { create(:business_claim, entry: entry, user: user) }
    let(:entry2) { create(:entry, :directory, tenant: tenant, category: category) }
    let!(:verified_claim) { create(:business_claim, :verified, entry: entry2, user: create(:user)) }

    it ".pending returns pending claims" do
      expect(BusinessClaim.pending).to include(pending_claim)
      expect(BusinessClaim.pending).not_to include(verified_claim)
    end

    it ".verified returns verified claims" do
      expect(BusinessClaim.verified).to include(verified_claim)
      expect(BusinessClaim.verified).not_to include(pending_claim)
    end
  end

  describe "instance methods" do
    let(:claim) { create(:business_claim, entry: entry, user: user) }

    it "#verify! transitions to verified and sets verified_at" do
      claim.verify!
      expect(claim.reload.status).to eq("verified")
      expect(claim.verified_at).to be_present
    end

    it "#reject! transitions to rejected" do
      claim.reject!
      expect(claim.reload.status).to eq("rejected")
    end
  end
end
