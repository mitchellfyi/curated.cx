# frozen_string_literal: true

require "rails_helper"

RSpec.describe ContentItemPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:content_item) { create(:content_item, :published, site: site, source: source) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#index?" do
    context "when tenant does not require login" do
      before { allow(tenant).to receive(:requires_login?).and_return(false) }

      it "allows access for any user" do
        policy = described_class.new(user, content_item)
        expect(policy.index?).to be true
      end

      it "allows access for nil user" do
        policy = described_class.new(nil, content_item)
        expect(policy.index?).to be true
      end
    end

    context "when tenant requires login" do
      before { allow(tenant).to receive(:requires_login?).and_return(true) }

      it "allows access for logged in user" do
        policy = described_class.new(user, content_item)
        expect(policy.index?).to be true
      end

      it "denies access for nil user" do
        policy = described_class.new(nil, content_item)
        expect(policy.index?).to be false
      end
    end
  end

  describe "#show?" do
    context "when content item is published" do
      let(:published_item) { create(:content_item, :published, site: site, source: source) }

      context "when tenant does not require login" do
        before { allow(tenant).to receive(:requires_login?).and_return(false) }

        it "allows access for any user" do
          policy = described_class.new(user, published_item)
          expect(policy.show?).to be true
        end

        it "allows access for nil user" do
          policy = described_class.new(nil, published_item)
          expect(policy.show?).to be true
        end
      end

      context "when tenant requires login" do
        before { allow(tenant).to receive(:requires_login?).and_return(true) }

        it "allows access for logged in user" do
          policy = described_class.new(user, published_item)
          expect(policy.show?).to be true
        end

        it "denies access for nil user" do
          policy = described_class.new(nil, published_item)
          expect(policy.show?).to be false
        end
      end
    end

    context "when content item is not published" do
      let(:unpublished_item) { create(:content_item, :unpublished, site: site, source: source) }

      it "denies access for any user" do
        policy = described_class.new(user, unpublished_item)
        expect(policy.show?).to be false
      end

      it "denies access for nil user" do
        policy = described_class.new(nil, unpublished_item)
        expect(policy.show?).to be false
      end

      it "denies access for admin user" do
        policy = described_class.new(admin_user, unpublished_item)
        expect(policy.show?).to be false
      end
    end

    context "when record is nil" do
      it "denies access" do
        policy = described_class.new(user, nil)
        expect(policy.show?).to be false
      end
    end
  end

  describe "#create?" do
    context "when user is admin" do
      it "allows access" do
        policy = described_class.new(admin_user, content_item)
        expect(policy.create?).to be true
      end
    end

    context "when user has editor role" do
      before { user.add_role(:editor, tenant) }

      it "allows access" do
        policy = described_class.new(user, content_item)
        expect(policy.create?).to be true
      end
    end

    context "when user has admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, content_item)
        expect(policy.create?).to be true
      end
    end

    context "when user has owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, content_item)
        expect(policy.create?).to be true
      end
    end

    context "when user has viewer role" do
      before { user.add_role(:viewer, tenant) }

      it "denies access" do
        policy = described_class.new(user, content_item)
        expect(policy.create?).to be false
      end
    end

    context "when user has no roles" do
      it "denies access" do
        policy = described_class.new(user, content_item)
        expect(policy.create?).to be false
      end
    end

    context "when user is nil" do
      it "denies access" do
        policy = described_class.new(nil, content_item)
        expect(policy.create?).to be false
      end
    end
  end

  describe "#update?" do
    context "when user is admin" do
      it "allows access" do
        policy = described_class.new(admin_user, content_item)
        expect(policy.update?).to be true
      end
    end

    context "when user has editor role" do
      before { user.add_role(:editor, tenant) }

      it "allows access" do
        policy = described_class.new(user, content_item)
        expect(policy.update?).to be true
      end
    end

    context "when user has viewer role" do
      before { user.add_role(:viewer, tenant) }

      it "denies access" do
        policy = described_class.new(user, content_item)
        expect(policy.update?).to be false
      end
    end
  end

  describe "#destroy?" do
    context "when user is admin" do
      it "allows access" do
        policy = described_class.new(admin_user, content_item)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows access" do
        policy = described_class.new(user, content_item)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows access" do
        policy = described_class.new(user, content_item)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has editor role" do
      before { user.add_role(:editor, tenant) }

      it "denies access" do
        policy = described_class.new(user, content_item)
        expect(policy.destroy?).to be false
      end
    end

    context "when user has viewer role" do
      before { user.add_role(:viewer, tenant) }

      it "denies access" do
        policy = described_class.new(user, content_item)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "Scope" do
    let(:scope) { ContentItem.unscoped }
    let(:policy_scope) { described_class::Scope.new(user, scope) }

    context "when Current.site is present" do
      let!(:our_item) { create(:content_item, site: site, source: source) }
      let(:other_site) { create(:site, tenant: tenant) }
      let(:other_source) { create(:source, site: other_site) }
      let!(:other_item) { create(:content_item, site: other_site, source: other_source) }

      it "filters by site_id" do
        result = policy_scope.resolve
        expect(result).to include(our_item)
        expect(result).not_to include(other_item)
      end
    end

    context "when Current.site is nil" do
      before { allow(Current).to receive(:site).and_return(nil) }

      it "returns no content items" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
