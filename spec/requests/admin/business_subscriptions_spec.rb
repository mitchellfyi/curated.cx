# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::BusinessSubscriptions", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:category) { create(:category, site: site, tenant: tenant) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    sign_in admin_user
  end

  describe "GET /admin/business_subscriptions" do
    context "when there are no subscriptions" do
      it "returns http success" do
        get admin_business_subscriptions_path

        expect(response).to have_http_status(:success)
      end
    end

    context "when there are subscriptions" do
      let!(:entry) { create(:entry, :directory, site: site, category: category) }
      let!(:subscriptions) do
        [
          create(:business_subscription, :pro, entry: entry),
          create(:business_subscription, :premium, entry: create(:entry, :directory, site: site, category: category)),
          create(:business_subscription, :cancelled, entry: create(:entry, :directory, site: site, category: category))
        ]
      end

      it "returns http success" do
        get admin_business_subscriptions_path

        expect(response).to have_http_status(:success)
      end

      it "displays all subscriptions" do
        get admin_business_subscriptions_path

        expect(assigns(:subscriptions).size).to eq(3)
      end

      it "eager loads entry and user associations" do
        expect do
          get admin_business_subscriptions_path
        end.not_to exceed_query_limit(15)
      end
    end

    context "with tier filter" do
      let!(:entry1) { create(:entry, :directory, site: site, category: category) }
      let!(:entry2) { create(:entry, :directory, site: site, category: category) }
      let!(:pro_subscription) { create(:business_subscription, :pro, entry: entry1) }
      let!(:premium_subscription) { create(:business_subscription, :premium, entry: entry2) }

      it "filters by pro tier" do
        get admin_business_subscriptions_path(tier: "pro")

        expect(assigns(:subscriptions)).to include(pro_subscription)
        expect(assigns(:subscriptions)).not_to include(premium_subscription)
      end

      it "filters by premium tier" do
        get admin_business_subscriptions_path(tier: "premium")

        expect(assigns(:subscriptions)).to include(premium_subscription)
        expect(assigns(:subscriptions)).not_to include(pro_subscription)
      end
    end

    context "with status filter" do
      let!(:entry1) { create(:entry, :directory, site: site, category: category) }
      let!(:entry2) { create(:entry, :directory, site: site, category: category) }
      let!(:active_subscription) { create(:business_subscription, entry: entry1) }
      let!(:cancelled_subscription) { create(:business_subscription, :cancelled, entry: entry2) }

      it "filters by active status" do
        get admin_business_subscriptions_path(status: "active")

        expect(assigns(:subscriptions)).to include(active_subscription)
        expect(assigns(:subscriptions)).not_to include(cancelled_subscription)
      end

      it "filters by cancelled status" do
        get admin_business_subscriptions_path(status: "cancelled")

        expect(assigns(:subscriptions)).to include(cancelled_subscription)
        expect(assigns(:subscriptions)).not_to include(active_subscription)
      end
    end
  end

  describe "GET /admin/business_subscriptions/:id" do
    let!(:entry) { create(:entry, :directory, site: site, category: category) }
    let!(:subscription) { create(:business_subscription, :with_stripe, entry: entry) }

    it "returns http success" do
      get admin_business_subscription_path(subscription)

      expect(response).to have_http_status(:success)
    end

    it "displays subscription details" do
      get admin_business_subscription_path(subscription)

      expect(response.body).to include(subscription.entry.title)
      expect(response.body).to include(subscription.user.email)
      expect(response.body).to include(subscription.tier.titleize)
    end

    it "prevents N+1 queries by eager loading" do
      expect do
        get admin_business_subscription_path(subscription)
      end.not_to exceed_query_limit(10)
    end
  end

  describe "POST /admin/business_subscriptions/:id/cancel" do
    let!(:entry) { create(:entry, :directory, site: site, category: category) }
    let!(:subscription) { create(:business_subscription, entry: entry) }

    it "cancels the subscription" do
      expect do
        post cancel_admin_business_subscription_path(subscription)
      end.to change { subscription.reload.status }.from("active").to("cancelled")
    end

    it "redirects to the subscription show page" do
      post cancel_admin_business_subscription_path(subscription)

      expect(response).to redirect_to(admin_business_subscription_path(subscription))
    end

    it "displays a success notice" do
      post cancel_admin_business_subscription_path(subscription)

      follow_redirect!
      expect(response.body).to include("cancelled")
    end

    context "when subscription is already cancelled" do
      let!(:cancelled_subscription) { create(:business_subscription, :cancelled, entry: entry) }

      it "does not change status" do
        expect do
          post cancel_admin_business_subscription_path(cancelled_subscription)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe "authorization" do
    context "when not signed in" do
      before { sign_out admin_user }

      it "redirects to sign in" do
        get admin_business_subscriptions_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      let(:regular_user) { create(:user) }

      before do
        sign_out admin_user
        sign_in regular_user
      end

      it "denies access" do
        get admin_business_subscriptions_path

        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "site scoping" do
    let!(:other_tenant) { create(:tenant, :enabled) }
    let!(:other_site) { create(:site, tenant: other_tenant) }
    let!(:other_category) { create(:category, site: other_site, tenant: other_tenant) }
    let!(:other_entry) { create(:entry, :directory, site: other_site, category: other_category) }
    let!(:other_subscription) { create(:business_subscription, entry: other_entry) }

    it "only shows subscriptions for current site" do
      get admin_business_subscriptions_path

      expect(assigns(:subscriptions)).not_to include(other_subscription)
    end

    it "raises not found for subscriptions from other sites" do
      expect do
        get admin_business_subscription_path(other_subscription)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
