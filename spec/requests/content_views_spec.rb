# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ContentViews", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:content_item) { create(:content_item, :published, site: site, source: source) }
  let(:user) { create(:user) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "POST /content_items/:content_item_id/views" do
    context "when user is authenticated" do
      before { sign_in user }

      context "when user has not viewed the content" do
        it "creates a new content view" do
          expect {
            post content_item_views_path(content_item), as: :json
          }.to change(ContentView, :count).by(1)

          expect(response).to have_http_status(:ok)
        end

        it "returns success response" do
          post content_item_views_path(content_item), as: :json

          json = JSON.parse(response.body)
          expect(json["success"]).to be true
        end

        it "creates view with correct attributes" do
          post content_item_views_path(content_item), as: :json

          view = ContentView.last
          expect(view.user).to eq(user)
          expect(view.content_item).to eq(content_item)
          expect(view.site).to eq(site)
          expect(view.viewed_at).to be_present
        end
      end

      context "when user has already viewed the content" do
        let!(:existing_view) do
          create(:content_view, content_item: content_item, user: user, site: site, viewed_at: 1.day.ago)
        end

        it "does not create a duplicate view (idempotent)" do
          expect {
            post content_item_views_path(content_item), as: :json
          }.not_to change(ContentView, :count)

          expect(response).to have_http_status(:ok)
        end

        it "updates the viewed_at timestamp" do
          original_viewed_at = existing_view.viewed_at

          post content_item_views_path(content_item), as: :json

          existing_view.reload
          expect(existing_view.viewed_at).to be > original_viewed_at
        end

        it "returns success response" do
          post content_item_views_path(content_item), as: :json

          json = JSON.parse(response.body)
          expect(json["success"]).to be true
        end
      end

      context "with HTML format" do
        it "returns ok status" do
          post content_item_views_path(content_item)

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post content_item_views_path(content_item)

        expect(response).to redirect_to(new_user_session_path)
      end

      it "does not create a view" do
        expect {
          post content_item_views_path(content_item)
        }.not_to change(ContentView, :count)
      end
    end

    context "when content item does not exist" do
      before { sign_in user }

      it "returns not found" do
        post content_item_views_path(999999), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "site isolation" do
    let(:other_tenant) { create(:tenant, :enabled) }
    let(:other_site) { other_tenant.sites.first || create(:site, tenant: other_tenant) }
    let(:other_source) { create(:source, site: other_site) }
    let(:other_content_item) { create(:content_item, :published, site: other_site, source: other_source) }

    before { sign_in user }

    it "creates views for current site" do
      post content_item_views_path(content_item), as: :json

      view = ContentView.last
      expect(view.site).to eq(site)
    end

    it "allows same user to view content on different sites" do
      # View on first site
      post content_item_views_path(content_item), as: :json
      expect(response).to have_http_status(:ok)
      expect(ContentView.count).to eq(1)

      # Switch to other tenant context
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)

      # View on other site (re-sign in for the new site context)
      sign_in user
      post content_item_views_path(other_content_item), as: :json
      expect(response).to have_http_status(:ok)
      expect(ContentView.without_site_scope.count).to eq(2)
    end
  end
end
