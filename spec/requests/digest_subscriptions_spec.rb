# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DigestSubscriptions", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /digest_subscription" do
    context "when not signed in" do
      it "redirects to sign in" do
        get digest_subscription_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns http success" do
        get digest_subscription_path

        expect(response).to have_http_status(:success)
      end

      it "shows existing subscription" do
        subscription = create(:digest_subscription, user: user, site: site)

        get digest_subscription_path

        expect(assigns(:subscription)).to eq(subscription)
      end
    end
  end

  describe "POST /digest_subscription" do
    context "when not signed in" do
      it "redirects to sign in" do
        post digest_subscription_path, params: { digest_subscription: { frequency: :weekly } }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "creates a subscription" do
        expect {
          post digest_subscription_path, params: { digest_subscription: { frequency: :weekly } }
        }.to change(DigestSubscription, :count).by(1)

        expect(response).to redirect_to(digest_subscription_path)
      end

      it "sets the correct attributes" do
        post digest_subscription_path, params: { digest_subscription: { frequency: :daily } }

        subscription = DigestSubscription.last
        expect(subscription.user).to eq(user)
        expect(subscription.site).to eq(site)
        expect(subscription.frequency).to eq("daily")
        expect(subscription.active).to be true
      end
    end
  end

  describe "PATCH /digest_subscription" do
    let!(:subscription) { create(:digest_subscription, user: user, site: site, frequency: :weekly) }

    context "when signed in" do
      before { sign_in user }

      it "updates the subscription" do
        patch digest_subscription_path, params: { digest_subscription: { frequency: :daily } }

        expect(response).to redirect_to(digest_subscription_path)
        expect(subscription.reload.frequency).to eq("daily")
      end
    end
  end

  describe "DELETE /digest_subscription" do
    let!(:subscription) { create(:digest_subscription, user: user, site: site) }

    context "when signed in" do
      before { sign_in user }

      it "unsubscribes" do
        delete digest_subscription_path

        expect(response).to redirect_to(digest_subscription_path)
        expect(subscription.reload.active).to be false
      end
    end
  end

  describe "GET /unsubscribe/:token" do
    let!(:subscription) { create(:digest_subscription, user: user, site: site) }

    it "unsubscribes with valid token" do
      get unsubscribe_digest_path(token: subscription.unsubscribe_token)

      expect(response).to have_http_status(:success)
      expect(subscription.reload.active).to be false
    end

    it "shows error with invalid token" do
      get unsubscribe_digest_path(token: "invalid")

      expect(response).to have_http_status(:not_found)
    end
  end
end
