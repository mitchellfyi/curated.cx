# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::DigestSubscriptions", type: :request do
  let!(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:tenant_owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "authentication and authorization" do
    describe "GET /admin/digest_subscriptions" do
      context "when not signed in" do
        it "redirects to sign in" do
          get admin_digest_subscriptions_path

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when signed in as regular user" do
        before { sign_in regular_user }

        it "denies access" do
          get admin_digest_subscriptions_path

          expect(response).to redirect_to(root_path)
        end
      end

      context "when signed in as admin" do
        before { sign_in admin_user }

        it "allows access" do
          get admin_digest_subscriptions_path

          expect(response).to have_http_status(:success)
        end
      end

      context "when signed in as tenant owner" do
        before { sign_in tenant_owner }

        it "allows access" do
          get admin_digest_subscriptions_path

          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/digest_subscriptions" do
    before { sign_in admin_user }

    context "with no subscriptions" do
      it "shows empty list" do
        get admin_digest_subscriptions_path

        expect(assigns(:digest_subscriptions)).to be_empty
      end
    end

    context "with subscriptions" do
      let!(:user1) { create(:user) }
      let!(:user2) { create(:user) }
      let!(:old_sub) { create(:digest_subscription, user: user1, site: site, created_at: 2.days.ago) }
      let!(:new_sub) { create(:digest_subscription, user: user2, site: site, created_at: 1.day.ago) }

      it "shows subscriptions ordered by most recent first" do
        get admin_digest_subscriptions_path

        subs = assigns(:digest_subscriptions)
        expect(subs.first).to eq(new_sub)
        expect(subs.last).to eq(old_sub)
      end

      it "includes subscriber tags" do
        tag = create(:subscriber_tag, site: site, name: "VIP")
        create(:subscriber_tagging, digest_subscription: new_sub, subscriber_tag: tag)

        get admin_digest_subscriptions_path

        subs = assigns(:digest_subscriptions)
        expect(subs.first.subscriber_tags).to include(tag)
      end
    end

    context "tenant isolation" do
      let!(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let!(:other_user) { create(:user) }
      let!(:other_sub) do
        ActsAsTenant.without_tenant do
          create(:digest_subscription, user: other_user, site: other_site)
        end
      end
      let!(:site_user) { create(:user) }
      let!(:site_sub) { create(:digest_subscription, user: site_user, site: site) }

      it "only shows subscriptions for current site" do
        get admin_digest_subscriptions_path

        expect(assigns(:digest_subscriptions)).to include(site_sub)
        expect(assigns(:digest_subscriptions)).not_to include(other_sub)
      end
    end

    context "with many subscriptions" do
      before do
        30.times do
          user = create(:user)
          create(:digest_subscription, user: user, site: site)
        end
      end

      it "limits results to 100" do
        get admin_digest_subscriptions_path

        expect(assigns(:digest_subscriptions).size).to eq(30)
      end
    end
  end

  describe "GET /admin/digest_subscriptions/:id" do
    let!(:user) { create(:user) }
    let!(:subscription) { create(:digest_subscription, user: user, site: site) }

    before { sign_in admin_user }

    it "shows subscription details" do
      get admin_digest_subscription_path(subscription)

      expect(response).to have_http_status(:success)
      expect(assigns(:digest_subscription)).to eq(subscription)
    end

    it "loads available tags" do
      tag = create(:subscriber_tag, site: site, name: "VIP")

      get admin_digest_subscription_path(subscription)

      expect(assigns(:subscriber_tags)).to include(tag)
    end
  end

  describe "PATCH /admin/digest_subscriptions/:id/update_tags" do
    let!(:user) { create(:user) }
    let!(:subscription) { create(:digest_subscription, user: user, site: site) }
    let!(:tag1) { create(:subscriber_tag, site: site, name: "VIP") }
    let!(:tag2) { create(:subscriber_tag, site: site, name: "Beta") }

    before { sign_in admin_user }

    context "HTML format" do
      it "adds tags to subscription" do
        patch update_tags_admin_digest_subscription_path(subscription), params: {
          tag_ids: [ tag1.id, tag2.id ]
        }

        expect(subscription.reload.subscriber_tags).to include(tag1, tag2)
        expect(response).to redirect_to(admin_digest_subscription_path(subscription))
      end

      it "removes tags when not included" do
        create(:subscriber_tagging, digest_subscription: subscription, subscriber_tag: tag1)

        patch update_tags_admin_digest_subscription_path(subscription), params: {
          tag_ids: []
        }

        expect(subscription.reload.subscriber_tags).to be_empty
      end

      it "replaces tags completely" do
        create(:subscriber_tagging, digest_subscription: subscription, subscriber_tag: tag1)

        patch update_tags_admin_digest_subscription_path(subscription), params: {
          tag_ids: [ tag2.id ]
        }

        expect(subscription.reload.subscriber_tags).to eq([ tag2 ])
      end
    end

    context "JSON format" do
      it "returns success response" do
        patch update_tags_admin_digest_subscription_path(subscription), params: {
          tag_ids: [ tag1.id ]
        }, as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["tags"]).to eq([ "VIP" ])
      end
    end
  end
end
