# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscussionPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:discussion) { build(:discussion, site: site, user: user) }

  before do
    allow(Current).to receive(:site).and_return(site)
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "#index?" do
    it "allows anyone to view discussions" do
      policy = described_class.new(nil, Discussion)
      expect(policy.index?).to be true
    end

    it "allows logged in users to view discussions" do
      policy = described_class.new(user, Discussion)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    context "when discussion is public" do
      let(:discussion) { build(:discussion, site: site, user: user, visibility: :public_access) }

      it "allows anyone to view" do
        policy = described_class.new(nil, discussion)
        expect(policy.show?).to be true
      end

      it "allows logged in users to view" do
        policy = described_class.new(user, discussion)
        expect(policy.show?).to be true
      end
    end

    context "when discussion is subscribers_only" do
      let(:discussion) { build(:discussion, :subscribers_only, site: site, user: user) }

      it "denies anonymous users" do
        policy = described_class.new(nil, discussion)
        expect(policy.show?).to be false
      end

      it "denies non-subscribers" do
        policy = described_class.new(other_user, discussion)
        expect(policy.show?).to be false
      end

      it "allows subscribers" do
        create(:digest_subscription, user: other_user, site: site, active: true)
        policy = described_class.new(other_user, discussion)
        expect(policy.show?).to be true
      end

      it "denies inactive subscribers" do
        create(:digest_subscription, user: other_user, site: site, active: false)
        policy = described_class.new(other_user, discussion)
        expect(policy.show?).to be false
      end

      it "allows admins" do
        policy = described_class.new(admin_user, discussion)
        expect(policy.show?).to be true
      end
    end
  end

  describe "#create?" do
    context "when discussions are enabled" do
      before do
        allow(site).to receive(:discussions_enabled?).and_return(true)
      end

      context "when user is present and not banned" do
        it "allows creating a discussion" do
          policy = described_class.new(user, discussion)
          expect(policy.create?).to be true
        end
      end

      context "when user is nil" do
        it "denies creating a discussion" do
          policy = described_class.new(nil, discussion)
          expect(policy.create?).to be false
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin_user)
        end

        it "denies creating a discussion" do
          policy = described_class.new(user, discussion)
          expect(policy.create?).to be false
        end
      end
    end

    context "when discussions are disabled" do
      before do
        allow(site).to receive(:discussions_enabled?).and_return(false)
      end

      it "denies creating a discussion" do
        policy = described_class.new(user, discussion)
        expect(policy.create?).to be false
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "denies creating a discussion" do
        policy = described_class.new(user, discussion)
        expect(policy.create?).to be false
      end
    end
  end

  describe "#update?" do
    let!(:existing_discussion) { create(:discussion, site: site, user: user) }

    context "when user is the discussion author and not banned" do
      it "allows updating the discussion" do
        policy = described_class.new(user, existing_discussion)
        expect(policy.update?).to be true
      end
    end

    context "when user is not the discussion author" do
      it "denies updating the discussion" do
        policy = described_class.new(other_user, existing_discussion)
        expect(policy.update?).to be false
      end
    end

    context "when user is banned" do
      before do
        create(:site_ban, site: site, user: user, banned_by: admin_user)
      end

      it "denies updating the discussion" do
        policy = described_class.new(user, existing_discussion)
        expect(policy.update?).to be false
      end
    end

    context "when user is nil" do
      it "denies updating the discussion" do
        policy = described_class.new(nil, existing_discussion)
        expect(policy.update?).to be false
      end
    end

    context "when user is global admin but not author" do
      it "allows updating the discussion" do
        policy = described_class.new(admin_user, existing_discussion)
        expect(policy.update?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { other_user.add_role(:owner, tenant) }

      it "allows updating the discussion" do
        policy = described_class.new(other_user, existing_discussion)
        expect(policy.update?).to be true
      end
    end
  end

  describe "#destroy?" do
    let!(:existing_discussion) { create(:discussion, site: site, user: user) }

    context "when user is global admin" do
      it "allows destroying the discussion" do
        policy = described_class.new(admin_user, existing_discussion)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows destroying the discussion" do
        policy = described_class.new(user, existing_discussion)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows destroying the discussion" do
        policy = described_class.new(user, existing_discussion)
        expect(policy.destroy?).to be true
      end
    end

    context "when user is only discussion author (no admin role)" do
      it "denies destroying the discussion" do
        # Make sure the user has no roles
        policy = described_class.new(other_user, existing_discussion)
        expect(policy.destroy?).to be false
      end
    end

    context "when user is nil" do
      it "denies destroying the discussion" do
        policy = described_class.new(nil, existing_discussion)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "Scope" do
    let(:policy_scope) { described_class::Scope.new(user, Discussion.unscoped) }
    let!(:public_discussion) { create(:discussion, site: site, user: user, visibility: :public_access) }
    let!(:subscribers_only_discussion) { create(:discussion, :subscribers_only, site: site, user: user) }

    context "when Current.site is present" do
      before do
        # Create other tenant's data outside tenant scope
        @other_discussion = ActsAsTenant.without_tenant do
          other_tenant = create(:tenant)
          other_site = other_tenant.sites.first
          create(:discussion, site: other_site, user: create(:user))
        end
        allow(Current).to receive(:site).and_return(site)
      end

      context "when user is not subscribed" do
        it "returns only public discussions for the site" do
          result = policy_scope.resolve
          expect(result).to include(public_discussion)
          expect(result).not_to include(subscribers_only_discussion)
          expect(result).not_to include(@other_discussion)
        end
      end

      context "when user is subscribed" do
        before do
          create(:digest_subscription, user: user, site: site, active: true)
        end

        it "returns all discussions for the site" do
          result = policy_scope.resolve
          expect(result).to include(public_discussion, subscribers_only_discussion)
          expect(result).not_to include(@other_discussion)
        end
      end

      context "when user is admin" do
        it "returns all discussions for the site" do
          admin_scope = described_class::Scope.new(admin_user, Discussion.unscoped)
          result = admin_scope.resolve
          expect(result).to include(public_discussion, subscribers_only_discussion)
          expect(result).not_to include(@other_discussion)
        end
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "returns no discussions" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
