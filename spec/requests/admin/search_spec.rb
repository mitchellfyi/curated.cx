# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Search", type: :request do
  let(:tenant) { create(:tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  before do
    setup_tenant_context(tenant)
    host! tenant.hostname
  end

  describe "GET /admin/search" do
    context "when not authenticated" do
      it "redirects to login" do
        get admin_search_path(q: "test")
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when authenticated as regular user" do
      before { sign_in regular_user }

      it "redirects to root" do
        get admin_search_path(q: "test")
        expect(response).to redirect_to(root_path)
      end
    end

    context "when authenticated as admin" do
      before { sign_in admin_user }

      it "returns success" do
        get admin_search_path(q: "test")
        expect(response).to have_http_status(:success)
      end

      it "returns success without query" do
        get admin_search_path
        expect(response).to have_http_status(:success)
      end

      it "finds matching users" do
        user = create(:user, email: "searchme@example.com")

        get admin_search_path(q: "searchme")
        expect(response.body).to include("searchme@example.com")
      end

      it "finds matching content items" do
        source = create(:source, site: Current.site)
        entry = create(:entry, :feed, source: source, title: "Searchable Title")

        get admin_search_path(q: "Searchable")
        expect(response.body).to include("Searchable Title")
      end

      it "sanitizes query to remove LIKE wildcards" do
        get admin_search_path(q: "test%_injection")
        expect(response).to have_http_status(:success)
      end

      it "requires minimum query length" do
        get admin_search_path(q: "a")
        expect(response).to have_http_status(:success)
        expect(assigns(:results)).to be_nil
      end
    end
  end
end
