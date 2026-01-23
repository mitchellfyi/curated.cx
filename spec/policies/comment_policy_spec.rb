# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommentPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:content_item) { create(:content_item, site: site, source: source) }
  let(:comment) { build(:comment, content_item: content_item, user: user, site: site) }

  before do
    allow(Current).to receive(:site).and_return(site)
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "#index?" do
    it "allows anyone to view comments" do
      policy = described_class.new(nil, Comment)
      expect(policy.index?).to be true
    end

    it "allows logged in users to view comments" do
      policy = described_class.new(user, Comment)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    it "allows anyone to view a comment" do
      policy = described_class.new(nil, comment)
      expect(policy.show?).to be true
    end
  end

  describe "#create?" do
    context "when user is present and not banned" do
      it "allows creating a comment" do
        policy = described_class.new(user, comment)
        expect(policy.create?).to be true
      end
    end

    context "when user is nil" do
      it "denies creating a comment" do
        policy = described_class.new(nil, comment)
        expect(policy.create?).to be false
      end
    end

    context "when user is banned" do
      before do
        create(:site_ban, site: site, user: user, banned_by: admin_user)
      end

      it "denies creating a comment" do
        policy = described_class.new(user, comment)
        expect(policy.create?).to be false
      end
    end

    context "when comments are locked on content item" do
      let(:locked_content_item) { create(:content_item, :comments_locked, site: site, source: source) }
      let(:comment_on_locked) { build(:comment, content_item: locked_content_item, user: user, site: site) }

      it "denies creating a comment" do
        policy = described_class.new(user, comment_on_locked)
        expect(policy.create?).to be false
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "denies creating a comment" do
        policy = described_class.new(user, comment)
        expect(policy.create?).to be false
      end
    end
  end

  describe "#update?" do
    let!(:existing_comment) { create(:comment, content_item: content_item, user: user, site: site) }

    context "when user is the comment author and not banned" do
      it "allows updating the comment" do
        policy = described_class.new(user, existing_comment)
        expect(policy.update?).to be true
      end
    end

    context "when user is not the comment author" do
      it "denies updating the comment" do
        policy = described_class.new(other_user, existing_comment)
        expect(policy.update?).to be false
      end
    end

    context "when user is banned" do
      before do
        create(:site_ban, site: site, user: user, banned_by: admin_user)
      end

      it "denies updating the comment" do
        policy = described_class.new(user, existing_comment)
        expect(policy.update?).to be false
      end
    end

    context "when user is nil" do
      it "denies updating the comment" do
        policy = described_class.new(nil, existing_comment)
        expect(policy.update?).to be false
      end
    end

    context "when admin is not the author" do
      it "denies updating the comment (admin cannot edit others' comments)" do
        policy = described_class.new(admin_user, existing_comment)
        expect(policy.update?).to be false
      end
    end
  end

  describe "#destroy?" do
    let!(:existing_comment) { create(:comment, content_item: content_item, user: user, site: site) }

    context "when user is global admin" do
      it "allows destroying the comment" do
        policy = described_class.new(admin_user, existing_comment)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows destroying the comment" do
        policy = described_class.new(user, existing_comment)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { user.add_role(:admin, tenant) }

      it "allows destroying the comment" do
        policy = described_class.new(user, existing_comment)
        expect(policy.destroy?).to be true
      end
    end

    context "when user is only comment author (no admin role)" do
      it "denies destroying the comment" do
        policy = described_class.new(user, existing_comment)
        expect(policy.destroy?).to be false
      end
    end

    context "when user has editor role only" do
      before { other_user.add_role(:editor, tenant) }

      it "denies destroying the comment" do
        policy = described_class.new(other_user, existing_comment)
        expect(policy.destroy?).to be false
      end
    end

    context "when user is nil" do
      it "denies destroying the comment" do
        policy = described_class.new(nil, existing_comment)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "Scope" do
    let(:policy_scope) { described_class::Scope.new(user, Comment.unscoped) }
    let!(:our_comment) { create(:comment, content_item: content_item, user: user, site: site) }

    context "when Current.site is present" do
      let(:other_tenant) { create(:tenant) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let(:other_source) { create(:source, site: other_site) }
      let(:other_content_item) { create(:content_item, site: other_site, source: other_source) }

      before do
        Current.site = other_site
        @other_comment = create(:comment, content_item: other_content_item, user: create(:user), site: other_site)
        Current.site = site
        allow(Current).to receive(:site).and_return(site)
      end

      it "filters by site_id" do
        result = policy_scope.resolve
        expect(result).to include(our_comment)
        expect(result).not_to include(@other_comment)
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "returns no comments" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
