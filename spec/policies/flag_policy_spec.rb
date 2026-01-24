# frozen_string_literal: true

require "rails_helper"

RSpec.describe FlagPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:content_item) { create(:content_item, site: site, source: source) }
  let(:content_owner) { create(:user) }
  let(:comment) { create(:comment, content_item: content_item, user: content_owner, site: site) }
  let(:flag) { build(:flag, flaggable: content_item, user: user, site: site) }

  before do
    allow(Current).to receive(:site).and_return(site)
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "#create?" do
    context "when user is present and not banned" do
      it "allows creating a flag" do
        policy = described_class.new(user, flag)
        expect(policy.create?).to be true
      end
    end

    context "when user is nil" do
      it "denies creating a flag" do
        policy = described_class.new(nil, flag)
        expect(policy.create?).to be false
      end
    end

    context "when user is banned" do
      before do
        create(:site_ban, site: site, user: user, banned_by: admin)
      end

      it "denies creating a flag" do
        policy = described_class.new(user, flag)
        expect(policy.create?).to be false
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "denies creating a flag" do
        policy = described_class.new(user, flag)
        expect(policy.create?).to be false
      end
    end

    context "when flagging own content" do
      let(:own_comment) { create(:comment, content_item: content_item, user: user, site: site) }
      let(:flag_own) { build(:flag, flaggable: own_comment, user: user, site: site) }

      it "denies flagging own comment" do
        policy = described_class.new(user, flag_own)
        expect(policy.create?).to be false
      end
    end

    context "when flagging others' content" do
      it "allows flagging others' comment" do
        flag_other = build(:flag, flaggable: comment, user: user, site: site)
        policy = described_class.new(user, flag_other)
        expect(policy.create?).to be true
      end

      it "allows flagging content items (no owner)" do
        policy = described_class.new(user, flag)
        expect(policy.create?).to be true
      end
    end
  end

  describe "#index?" do
    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin, Flag)
        expect(policy.index?).to be true
      end
    end

    context "when user is tenant owner" do
      let(:owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }

      it "allows access" do
        policy = described_class.new(owner, Flag)
        expect(policy.index?).to be true
      end
    end

    context "when user is tenant admin" do
      let(:tenant_admin) { create(:user).tap { |u| u.add_role(:admin, tenant) } }

      it "allows access" do
        policy = described_class.new(tenant_admin, Flag)
        expect(policy.index?).to be true
      end
    end

    context "when user is regular user" do
      it "denies access" do
        policy = described_class.new(user, Flag)
        expect(policy.index?).to be false
      end
    end

    context "when user is nil" do
      it "denies access" do
        policy = described_class.new(nil, Flag)
        expect(policy.index?).to be false
      end
    end
  end

  describe "#show?" do
    let!(:existing_flag) { create(:flag, flaggable: content_item, user: user, site: site) }

    context "when user is global admin" do
      it "allows access" do
        policy = described_class.new(admin, existing_flag)
        expect(policy.show?).to be true
      end
    end

    context "when user is tenant owner" do
      let(:owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }

      it "allows access" do
        policy = described_class.new(owner, existing_flag)
        expect(policy.show?).to be true
      end
    end

    context "when user is regular user" do
      let(:other_user) { create(:user) }

      it "denies access" do
        policy = described_class.new(other_user, existing_flag)
        expect(policy.show?).to be false
      end
    end
  end

  describe "#resolve?" do
    let!(:existing_flag) { create(:flag, flaggable: content_item, user: user, site: site) }

    context "when user is global admin" do
      it "allows resolving" do
        policy = described_class.new(admin, existing_flag)
        expect(policy.resolve?).to be true
      end
    end

    context "when user is tenant owner" do
      let(:owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }

      it "allows resolving" do
        policy = described_class.new(owner, existing_flag)
        expect(policy.resolve?).to be true
      end
    end

    context "when user is regular user" do
      it "denies resolving" do
        policy = described_class.new(user, existing_flag)
        expect(policy.resolve?).to be false
      end
    end
  end

  describe "#dismiss?" do
    let!(:existing_flag) { create(:flag, flaggable: content_item, user: user, site: site) }

    context "when user is global admin" do
      it "allows dismissing" do
        policy = described_class.new(admin, existing_flag)
        expect(policy.dismiss?).to be true
      end
    end

    context "when user is tenant admin" do
      let(:tenant_admin) { create(:user).tap { |u| u.add_role(:admin, tenant) } }

      it "allows dismissing" do
        policy = described_class.new(tenant_admin, existing_flag)
        expect(policy.dismiss?).to be true
      end
    end

    context "when user is regular user" do
      it "denies dismissing" do
        policy = described_class.new(user, existing_flag)
        expect(policy.dismiss?).to be false
      end
    end
  end

  describe "Scope" do
    let(:policy_scope) { described_class::Scope.new(admin, Flag.unscoped) }
    let!(:our_flag) { create(:flag, flaggable: content_item, user: user, site: site) }

    context "when user is admin" do
      context "when Current.site is present" do
        before do
          # Create other tenant's data outside tenant scope
          @other_flag = ActsAsTenant.without_tenant do
            other_tenant = create(:tenant)
            other_site = other_tenant.sites.first
            other_source = create(:source, site: other_site, tenant: other_tenant)
            other_content_item = create(:content_item, site: other_site, source: other_source)
            create(:flag, flaggable: other_content_item, user: create(:user), site: other_site)
          end
          allow(Current).to receive(:site).and_return(site)
        end

        it "filters by site_id" do
          result = policy_scope.resolve
          expect(result).to include(our_flag)
          expect(result).not_to include(@other_flag)
        end
      end

      context "when Current.site is nil" do
        before do
          allow(Current).to receive(:site).and_return(nil)
        end

        it "returns no flags" do
          result = policy_scope.resolve
          expect(result).to be_empty
        end
      end
    end

    context "when user is regular user" do
      let(:user_policy_scope) { described_class::Scope.new(user, Flag.unscoped) }

      it "returns no flags" do
        result = user_policy_scope.resolve
        expect(result).to be_empty
      end
    end

    context "when user is nil" do
      let(:nil_policy_scope) { described_class::Scope.new(nil, Flag.unscoped) }

      it "returns no flags" do
        result = nil_policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
