# frozen_string_literal: true

require "rails_helper"

RSpec.describe LiveStreamPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin_user) { create(:user, admin: true) }
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:live_stream) { build(:live_stream, site: site, user: admin_user) }

  before do
    allow(Current).to receive(:site).and_return(site)
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "#index?" do
    it "allows anyone to view live streams" do
      policy = described_class.new(nil, LiveStream)
      expect(policy.index?).to be true
    end

    it "allows logged in users to view live streams" do
      policy = described_class.new(user, LiveStream)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    context "when live stream is public" do
      let(:live_stream) { build(:live_stream, site: site, user: admin_user, visibility: :public_access) }

      it "allows anyone to view" do
        policy = described_class.new(nil, live_stream)
        expect(policy.show?).to be true
      end

      it "allows logged in users to view" do
        policy = described_class.new(user, live_stream)
        expect(policy.show?).to be true
      end
    end

    context "when live stream is subscribers_only" do
      let(:live_stream) { build(:live_stream, :subscribers_only, site: site, user: admin_user) }

      it "denies anonymous users" do
        policy = described_class.new(nil, live_stream)
        expect(policy.show?).to be false
      end

      it "denies non-subscribers" do
        policy = described_class.new(other_user, live_stream)
        expect(policy.show?).to be false
      end

      it "allows subscribers" do
        create(:digest_subscription, user: other_user, site: site, active: true)
        policy = described_class.new(other_user, live_stream)
        expect(policy.show?).to be true
      end

      it "denies inactive subscribers" do
        create(:digest_subscription, user: other_user, site: site, active: false)
        policy = described_class.new(other_user, live_stream)
        expect(policy.show?).to be false
      end

      it "allows admins" do
        policy = described_class.new(admin_user, live_stream)
        expect(policy.show?).to be true
      end
    end
  end

  describe "#create?" do
    context "when streaming is enabled" do
      before do
        allow(site).to receive(:streaming_enabled?).and_return(true)
      end

      context "when user is global admin" do
        it "allows creating a live stream" do
          policy = described_class.new(admin_user, live_stream)
          expect(policy.create?).to be true
        end
      end

      context "when user has tenant owner role" do
        before { user.add_role(:owner, tenant) }

        it "allows creating a live stream" do
          policy = described_class.new(user, live_stream)
          expect(policy.create?).to be true
        end
      end

      context "when user has tenant admin role" do
        before { user.add_role(:admin, tenant) }

        it "allows creating a live stream" do
          policy = described_class.new(user, live_stream)
          expect(policy.create?).to be true
        end
      end

      context "when user has no admin role" do
        it "denies creating a live stream" do
          policy = described_class.new(user, live_stream)
          expect(policy.create?).to be false
        end
      end

      context "when user is nil" do
        it "denies creating a live stream" do
          policy = described_class.new(nil, live_stream)
          expect(policy.create?).to be false
        end
      end
    end

    context "when streaming is disabled" do
      before do
        allow(site).to receive(:streaming_enabled?).and_return(false)
      end

      it "denies creating a live stream" do
        policy = described_class.new(admin_user, live_stream)
        expect(policy.create?).to be false
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "denies creating a live stream" do
        policy = described_class.new(admin_user, live_stream)
        expect(policy.create?).to be false
      end
    end
  end

  describe "#update?" do
    context "when user is global admin" do
      it "allows updating the live stream" do
        policy = described_class.new(admin_user, live_stream)
        expect(policy.update?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows updating the live stream" do
        policy = described_class.new(user, live_stream)
        expect(policy.update?).to be true
      end
    end

    context "when user has no admin role" do
      it "denies updating the live stream" do
        policy = described_class.new(user, live_stream)
        expect(policy.update?).to be false
      end
    end

    context "when user is nil" do
      it "denies updating the live stream" do
        policy = described_class.new(nil, live_stream)
        expect(policy.update?).to be false
      end
    end
  end

  describe "#destroy?" do
    context "when user is global admin" do
      it "allows destroying the live stream" do
        policy = described_class.new(admin_user, live_stream)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has tenant owner role" do
      before { user.add_role(:owner, tenant) }

      it "allows destroying the live stream" do
        policy = described_class.new(user, live_stream)
        expect(policy.destroy?).to be true
      end
    end

    context "when user has no admin role" do
      it "denies destroying the live stream" do
        policy = described_class.new(user, live_stream)
        expect(policy.destroy?).to be false
      end
    end

    context "when user is nil" do
      it "denies destroying the live stream" do
        policy = described_class.new(nil, live_stream)
        expect(policy.destroy?).to be false
      end
    end
  end

  describe "#start?" do
    let(:scheduled_stream) { build(:live_stream, :scheduled, site: site, user: admin_user) }
    let(:live_stream_running) { build(:live_stream, :live, site: site, user: admin_user) }

    context "when stream can start" do
      context "when user is admin" do
        it "allows starting the stream" do
          policy = described_class.new(admin_user, scheduled_stream)
          expect(policy.start?).to be true
        end
      end

      context "when user has no admin role" do
        it "denies starting the stream" do
          policy = described_class.new(user, scheduled_stream)
          expect(policy.start?).to be false
        end
      end
    end

    context "when stream cannot start (already live)" do
      it "denies starting the stream" do
        policy = described_class.new(admin_user, live_stream_running)
        expect(policy.start?).to be false
      end
    end
  end

  describe "#end_stream?" do
    let(:live_stream_running) { build(:live_stream, :live, site: site, user: admin_user) }
    let(:scheduled_stream) { build(:live_stream, :scheduled, site: site, user: admin_user) }

    context "when stream can end" do
      context "when user is admin" do
        it "allows ending the stream" do
          policy = described_class.new(admin_user, live_stream_running)
          expect(policy.end_stream?).to be true
        end
      end

      context "when user has no admin role" do
        it "denies ending the stream" do
          policy = described_class.new(user, live_stream_running)
          expect(policy.end_stream?).to be false
        end
      end
    end

    context "when stream cannot end (not live)" do
      it "denies ending the stream" do
        policy = described_class.new(admin_user, scheduled_stream)
        expect(policy.end_stream?).to be false
      end
    end
  end

  describe "#join?" do
    it "delegates to show?" do
      public_stream = build(:live_stream, site: site, user: admin_user, visibility: :public_access)
      policy = described_class.new(nil, public_stream)
      expect(policy.join?).to eq(policy.show?)
    end
  end

  describe "#leave?" do
    it "always allows leaving" do
      policy = described_class.new(nil, live_stream)
      expect(policy.leave?).to be true
    end
  end

  describe "Scope" do
    let(:policy_scope) { described_class::Scope.new(user, LiveStream.unscoped) }
    let!(:public_stream) { create(:live_stream, site: site, user: admin_user, visibility: :public_access) }
    let!(:subscribers_only_stream) { create(:live_stream, :subscribers_only, site: site, user: admin_user) }

    context "when Current.site is present" do
      before do
        @other_stream = ActsAsTenant.without_tenant do
          other_tenant = create(:tenant)
          other_site = other_tenant.sites.first
          create(:live_stream, site: other_site, user: create(:user, :admin))
        end
        allow(Current).to receive(:site).and_return(site)
      end

      context "when user is not subscribed" do
        it "returns only public streams for the site" do
          result = policy_scope.resolve
          expect(result).to include(public_stream)
          expect(result).not_to include(subscribers_only_stream)
          expect(result).not_to include(@other_stream)
        end
      end

      context "when user is subscribed" do
        before do
          create(:digest_subscription, user: user, site: site, active: true)
        end

        it "returns all streams for the site" do
          result = policy_scope.resolve
          expect(result).to include(public_stream, subscribers_only_stream)
          expect(result).not_to include(@other_stream)
        end
      end

      context "when user is admin" do
        it "returns all streams for the site" do
          admin_scope = described_class::Scope.new(admin_user, LiveStream.unscoped)
          result = admin_scope.resolve
          expect(result).to include(public_stream, subscribers_only_stream)
          expect(result).not_to include(@other_stream)
        end
      end
    end

    context "when Current.site is nil" do
      before do
        allow(Current).to receive(:site).and_return(nil)
      end

      it "returns no streams" do
        result = policy_scope.resolve
        expect(result).to be_empty
      end
    end
  end
end
