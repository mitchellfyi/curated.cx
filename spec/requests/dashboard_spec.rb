# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }
  let(:tenant) { create(:tenant, :ai_news) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /dashboard" do
    context "when user is signed in" do
      before { sign_in user }

      it "renders the dashboard page successfully" do
        get dashboard_path
        expect(response).to have_http_status(:success)
      end

      it "assigns the correct counts" do
        # Create some bookmarks and submissions for the user
        entry = create(:entry, :feed, site: tenant.sites.first)
        create(:bookmark, user: user, bookmarkable: entry)
        create(:submission, user: user, site: tenant.sites.first)

        get dashboard_path

        expect(assigns(:bookmarks_count)).to eq(1)
        expect(assigns(:submissions_count)).to eq(1)
        expect(assigns(:purchases_count)).to eq(0)
      end
    end

    context "when user is not signed in" do
      it "redirects to sign in page" do
        get dashboard_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
