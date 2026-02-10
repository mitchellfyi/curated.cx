# frozen_string_literal: true

require "rails_helper"

RSpec.describe VotePolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:entry) { create(:entry, :feed, site: site, source: source) }
  let(:vote) { build(:vote, entry: entry, user: user, site: site) }

  before do
    allow(Current).to receive(:site).and_return(site)
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "#create?" do
    context "when user is present and not banned" do
      it "allows creating a vote" do
        policy = described_class.new(user, Vote)
        expect(policy.create?).to be true
      end
    end

    context "when user is nil" do
      it "denies creating a vote" do
        policy = described_class.new(nil, Vote)
        expect(policy.create?).to be false
      end
    end

    context "when user is banned" do
      before do
        create(:site_ban, site: site, user: user, banned_by: admin)
      end

      it "denies creating a vote" do
        policy = described_class.new(user, Vote)
        expect(policy.create?).to be false
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "denies creating a vote" do
        policy = described_class.new(user, Vote)
        expect(policy.create?).to be false
      end
    end
  end

  describe "#destroy?" do
    let!(:existing_vote) { create(:vote, entry: entry, user: user, site: site) }

    context "when user owns the vote and is not banned" do
      it "allows destroying the vote" do
        policy = described_class.new(user, existing_vote)
        expect(policy.destroy?).to be true
      end
    end

    context "when user does not own the vote" do
      let(:other_user) { create(:user) }

      it "denies destroying the vote" do
        policy = described_class.new(other_user, existing_vote)
        expect(policy.destroy?).to be false
      end
    end

    context "when user owns the vote but is banned" do
      before do
        create(:site_ban, site: site, user: user, banned_by: admin)
      end

      it "denies destroying the vote" do
        policy = described_class.new(user, existing_vote)
        expect(policy.destroy?).to be false
      end
    end

    context "when user is nil" do
      it "denies destroying the vote" do
        policy = described_class.new(nil, existing_vote)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "#toggle?" do
    context "when user is present and not banned" do
      it "allows toggling a vote" do
        policy = described_class.new(user, Vote)
        expect(policy.toggle?).to be true
      end
    end

    context "when user is nil" do
      it "denies toggling a vote" do
        policy = described_class.new(nil, Vote)
        expect(policy.toggle?).to be false
      end
    end

    context "when user is banned" do
      before do
        create(:site_ban, site: site, user: user, banned_by: admin)
      end

      it "denies toggling a vote" do
        policy = described_class.new(user, Vote)
        expect(policy.toggle?).to be false
      end
    end
  end

  describe "Scope" do
    let(:policy_scope) { described_class::Scope.new(user, Vote.unscoped) }
    let!(:our_vote) { create(:vote, entry: entry, user: user, site: site) }

    context "when Current.site is present" do
      before do
        # Create other tenant's data outside tenant scope
        @other_vote = ActsAsTenant.without_tenant do
          other_tenant = create(:tenant)
          other_site = other_tenant.sites.first
          other_source = create(:source, site: other_site, tenant: other_tenant)
          other_content_item = create(:entry, :feed, site: other_site, source: other_source)
          create(:vote, entry: other_content_item, user: create(:user), site: other_site)
        end
        allow(Current).to receive(:site).and_return(site)
      end

      it "filters by site_id" do
        result = policy_scope.resolve
        expect(result).to include(our_vote)
        expect(result).not_to include(@other_vote)
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "returns no votes" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
