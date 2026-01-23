# frozen_string_literal: true

require "rails_helper"

RSpec.describe SiteBanPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:banned_user) { create(:user) }
  let(:site_ban) { create(:site_ban, site: site, user: banned_user, banned_by: admin_user) }

  before do
    allow(Current).to receive(:site).and_return(site)
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "#index?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, SiteBan)
        expect(policy.index?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, SiteBan)
        expect(policy.index?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, SiteBan)
        expect(policy.index?).to be true
      end
    end

    context "when user has editor role" do
      before { user.add_role(:editor, tenant) }

      it "denies access" do
        policy = described_class.new(user, SiteBan)
        expect(policy.index?).to be false
      end
    end

    context "when user has no roles" do
      it "denies access" do
        policy = described_class.new(user, SiteBan)
        expect(policy.index?).to be false
      end
    end

    context "when user is nil" do
      it "denies access" do
        policy = described_class.new(nil, SiteBan)
        expect(policy.index?).to be false
      end
    end
  end

  describe "#show?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, site_ban)
        expect(policy.show?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, site_ban)
        expect(policy.show?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, site_ban)
        expect(policy.show?).to be true
      end
    end

    context "when user has no admin roles" do
      it "denies access" do
        policy = described_class.new(user, site_ban)
        expect(policy.show?).to be false
      end
    end
  end

  describe "#create?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, SiteBan)
        expect(policy.create?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, SiteBan)
        expect(policy.create?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, SiteBan)
        expect(policy.create?).to be true
      end
    end

    context "when user has editor role" do
      before { user.add_role(:editor, tenant) }

      it "denies access" do
        policy = described_class.new(user, SiteBan)
        expect(policy.create?).to be false
      end
    end

    context "when user has no roles" do
      it "denies access" do
        policy = described_class.new(user, SiteBan)
        expect(policy.create?).to be false
      end
    end
  end

  describe "#update?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, site_ban)
        expect(policy.update?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, site_ban)
        expect(policy.update?).to be true
      end
    end

    context "when user has no admin roles" do
      it "denies access" do
        policy = described_class.new(user, site_ban)
        expect(policy.update?).to be false
      end
    end
  end

  describe "#destroy?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin_user, site_ban)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, site_ban)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, site_ban)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has editor role" do
      before { user.add_role(:editor, tenant) }

      it "denies access" do
        policy = described_class.new(user, site_ban)
        expect(policy.destroy?).to be false
      end
    end

    context "when user has no roles" do
      it "denies access" do
        policy = described_class.new(user, site_ban)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "Scope" do
    context "when user is admin" do
      let(:policy_scope) { described_class::Scope.new(admin_user, SiteBan.unscoped) }

      context "when Current.site is present" do
        let(:other_tenant) { create(:tenant) }
        let(:other_site) { create(:site, tenant: other_tenant) }
        let!(:our_ban) { create(:site_ban, site: site, user: create(:user), banned_by: admin_user) }

        before do
          Current.site = other_site
          @other_ban = create(:site_ban, site: other_site, user: create(:user), banned_by: admin_user)
          Current.site = site
          allow(Current).to receive(:site).and_return(site)
        end

        it "filters by site_id" do
          result = policy_scope.resolve
          expect(result).to include(our_ban)
          expect(result).not_to include(@other_ban)
        end
      end

      context "when Current.site is nil" do
        before do
          allow(Current).to receive(:site).and_return(nil)
        end

        it "returns no bans" do
          result = policy_scope.resolve
          expect(result).to be_empty
        end
      end
    end

    context "when user is not admin" do
      let(:policy_scope) { described_class::Scope.new(user, SiteBan.unscoped) }
      let!(:ban) { create(:site_ban, site: site, user: create(:user), banned_by: admin_user) }

      it "returns no bans" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
