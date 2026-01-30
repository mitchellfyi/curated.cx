# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscussionPostPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:discussion) { create(:discussion, site: site, user: user) }
  let(:discussion_post) { build(:discussion_post, discussion: discussion, user: user, site: site) }

  before do
    allow(Current).to receive(:site).and_return(site)
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "#create?" do
    context "when user is present and not banned" do
      context "when discussion is not locked" do
        it "allows creating a post" do
          policy = described_class.new(user, discussion_post)
          expect(policy.create?).to be true
        end
      end

      context "when discussion is locked" do
        let(:locked_discussion) { create(:discussion, :locked, site: site, user: user) }
        let(:post_on_locked) { build(:discussion_post, discussion: locked_discussion, user: user, site: site) }

        it "denies creating a post" do
          policy = described_class.new(user, post_on_locked)
          expect(policy.create?).to be false
        end
      end
    end

    context "when user is nil" do
      it "denies creating a post" do
        policy = described_class.new(nil, discussion_post)
        expect(policy.create?).to be false
      end
    end

    context "when user is banned" do
      before do
        create(:site_ban, site: site, user: user, banned_by: admin_user)
      end

      it "denies creating a post" do
        policy = described_class.new(user, discussion_post)
        expect(policy.create?).to be false
      end
    end
  end

  describe "#update?" do
    let!(:existing_post) { create(:discussion_post, discussion: discussion, user: user, site: site) }

    context "when user is the post author and not banned" do
      it "allows updating the post" do
        policy = described_class.new(user, existing_post)
        expect(policy.update?).to be true
      end
    end

    context "when user is not the post author" do
      it "denies updating the post" do
        policy = described_class.new(other_user, existing_post)
        expect(policy.update?).to be false
      end
    end

    context "when user is banned" do
      before do
        create(:site_ban, site: site, user: user, banned_by: admin_user)
      end

      it "denies updating the post" do
        policy = described_class.new(user, existing_post)
        expect(policy.update?).to be false
      end
    end

    context "when user is nil" do
      it "denies updating the post" do
        policy = described_class.new(nil, existing_post)
        expect(policy.update?).to be false
      end
    end

    context "when admin is not the author" do
      it "denies updating the post (admin cannot edit others' posts)" do
        policy = described_class.new(admin_user, existing_post)
        expect(policy.update?).to be false
      end
    end
  end

  describe "#destroy?" do
    let!(:existing_post) { create(:discussion_post, discussion: discussion, user: user, site: site) }

    context "when user is the post author" do
      it "allows destroying the post" do
        policy = described_class.new(user, existing_post)
        expect(policy.destroy?).to be true
      end
    end

    context "when user is global admin" do
      it "allows destroying the post" do
        policy = described_class.new(admin_user, existing_post)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { other_user.add_role(:owner, tenant) }

      it "allows destroying the post" do
        policy = described_class.new(other_user, existing_post)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant admin role" do
      before { other_user.add_role(:admin, tenant) }

      it "allows destroying the post" do
        policy = described_class.new(other_user, existing_post)
        expect(policy.destroy?).to be true
      end
    end

    context "when user is neither author nor admin" do
      it "denies destroying the post" do
        policy = described_class.new(other_user, existing_post)
        expect(policy.destroy?).to be false
      end
    end

    context "when user is nil" do
      it "denies destroying the post" do
        policy = described_class.new(nil, existing_post)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "Scope" do
    let(:policy_scope) { described_class::Scope.new(user, DiscussionPost.unscoped) }
    let!(:our_post) { create(:discussion_post, discussion: discussion, user: user, site: site) }

    context "when Current.site is present" do
      before do
        # Create other tenant's data outside tenant scope
        @other_post = ActsAsTenant.without_tenant do
          other_tenant = create(:tenant)
          other_site = other_tenant.sites.first
          other_discussion = create(:discussion, site: other_site, user: create(:user))
          create(:discussion_post, discussion: other_discussion, user: create(:user), site: other_site)
        end
        allow(Current).to receive(:site).and_return(site)
      end

      it "filters by site_id" do
        result = policy_scope.resolve
        expect(result).to include(our_post)
        expect(result).not_to include(@other_post)
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "returns no posts" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
