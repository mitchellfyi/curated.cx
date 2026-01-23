# frozen_string_literal: true

require "rails_helper"

RSpec.describe SourcePolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :serp_api_google_news, site: site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "#index?" do
    context "when user is present and tenant context is set" do
      it "allows access" do
        policy = described_class.new(user, source)
        expect(policy.index?).to be true
      end
    end

    context "when user is nil" do
      it "denies access" do
        policy = described_class.new(nil, source)
        expect(policy.index?).to be false
      end
    end

    context "when tenant context is nil" do
      before { allow(Current).to receive(:tenant).and_return(nil) }

      it "denies access" do
        policy = described_class.new(user, source)
        expect(policy.index?).to be false
      end
    end
  end

  describe "#show?" do
    it "delegates to index?" do
      policy = described_class.new(user, source)
      expect(policy.show?).to eq(policy.index?)
    end
  end

  describe "#create?" do
    context "when user is present and tenant context is set" do
      it "allows access" do
        policy = described_class.new(user, source)
        expect(policy.create?).to be true
      end
    end

    context "when user is nil" do
      it "denies access" do
        policy = described_class.new(nil, source)
        expect(policy.create?).to be false
      end
    end

    context "when tenant context is nil" do
      before { allow(Current).to receive(:tenant).and_return(nil) }

      it "denies access" do
        policy = described_class.new(user, source)
        expect(policy.create?).to be false
      end
    end
  end

  describe "#new?" do
    it "delegates to create?" do
      policy = described_class.new(user, source)
      expect(policy.new?).to eq(policy.create?)
    end
  end

  describe "#update?" do
    context "when user is admin" do
      it "allows access" do
        policy = described_class.new(admin_user, source)
        expect(policy.update?).to be true
      end
    end

    context "when user belongs to the same tenant" do
      it "allows access" do
        policy = described_class.new(user, source)
        expect(policy.update?).to be true
      end
    end

    context "when source belongs to different tenant" do
      let(:other_source) do
        ActsAsTenant.without_tenant do
          other_tenant = create(:tenant)
          other_site = other_tenant.sites.first
          create(:source, :serp_api_google_news, site: other_site, tenant: other_tenant)
        end
      end

      it "denies access for non-admin user" do
        policy = described_class.new(user, other_source)
        expect(policy.update?).to be false
      end

      it "allows access for admin user" do
        policy = described_class.new(admin_user, other_source)
        expect(policy.update?).to be true
      end
    end

    context "when user is nil" do
      it "denies access" do
        policy = described_class.new(nil, source)
        expect(policy.update?).to be false
      end
    end
  end

  describe "#edit?" do
    it "delegates to update?" do
      policy = described_class.new(user, source)
      expect(policy.edit?).to eq(policy.update?)
    end
  end

  describe "#destroy?" do
    context "when user is admin" do
      it "allows access" do
        policy = described_class.new(admin_user, source)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has owner role for the tenant" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, source)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has editor role for the tenant" do
      before { user.add_role(:editor, tenant) }

      it "denies access" do
        policy = described_class.new(user, source)
        expect(policy.destroy?).to be false
      end
    end

    context "when user has no special roles" do
      it "denies access" do
        policy = described_class.new(user, source)
        expect(policy.destroy?).to be false
      end
    end

    context "when user is nil" do
      it "denies access" do
        policy = described_class.new(nil, source)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "#run_now?" do
    it "delegates to update?" do
      policy = described_class.new(user, source)
      expect(policy.run_now?).to eq(policy.update?)
    end

    context "when user is admin" do
      it "allows access" do
        policy = described_class.new(admin_user, source)
        expect(policy.run_now?).to be true
      end
    end

    context "when user belongs to the same tenant" do
      it "allows access" do
        policy = described_class.new(user, source)
        expect(policy.run_now?).to be true
      end
    end
  end

  describe "Scope" do
    let(:scope) { Source.unscoped }
    let(:policy_scope) { described_class::Scope.new(user, scope) }

    let!(:tenant1_source) { source }
    let!(:tenant2_source) do
      ActsAsTenant.without_tenant do
        other_tenant = create(:tenant)
        other_site = other_tenant.sites.first
        create(:source, :serp_api_google_news, site: other_site, tenant: other_tenant)
      end
    end

    context "when user is admin" do
      let(:policy_scope) { described_class::Scope.new(admin_user, scope) }

      it "returns all sources" do
        result = policy_scope.resolve
        expect(result).to include(tenant1_source)
        expect(result).to include(tenant2_source)
      end
    end

    context "when Current.tenant is present" do
      it "filters sources by tenant" do
        result = policy_scope.resolve
        expect(result).to include(tenant1_source)
        expect(result).not_to include(tenant2_source)
      end
    end

    context "when Current.tenant is nil" do
      before { allow(Current).to receive(:tenant).and_return(nil) }

      it "returns no sources" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end

    context "when user is nil" do
      let(:policy_scope) { described_class::Scope.new(nil, scope) }

      it "returns no sources" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
