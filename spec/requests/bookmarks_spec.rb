# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bookmarks", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:user) { create(:user) }
  let(:content_item) { create(:content_item, :published, site: site, source: source) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /bookmarks" do
    context "when not signed in" do
      it "redirects to sign in" do
        get bookmarks_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns http success" do
        get bookmarks_path

        expect(response).to have_http_status(:success)
      end

      it "shows user's bookmarks" do
        bookmark = create(:bookmark, user: user, bookmarkable: content_item)

        get bookmarks_path

        expect(assigns(:bookmarks)).to include(bookmark)
      end

      it "does not show other users bookmarks" do
        other_user = create(:user)
        other_bookmark = create(:bookmark, user: other_user, bookmarkable: content_item)

        get bookmarks_path

        expect(assigns(:bookmarks)).not_to include(other_bookmark)
      end
    end
  end

  describe "POST /bookmarks" do
    context "when not signed in" do
      it "redirects to sign in" do
        post bookmarks_path, params: { bookmarkable_type: "ContentItem", bookmarkable_id: content_item.id }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "creates a bookmark" do
        expect {
          post bookmarks_path, params: { bookmarkable_type: "ContentItem", bookmarkable_id: content_item.id }
        }.to change(Bookmark, :count).by(1)
      end

      it "associates bookmark with current user" do
        post bookmarks_path, params: { bookmarkable_type: "ContentItem", bookmarkable_id: content_item.id }

        expect(Bookmark.last.user).to eq(user)
        expect(Bookmark.last.bookmarkable).to eq(content_item)
      end

      it "responds with turbo stream" do
        post bookmarks_path,
          params: { bookmarkable_type: "ContentItem", bookmarkable_id: content_item.id },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end
    end
  end

  describe "DELETE /bookmarks/:id" do
    let!(:bookmark) { create(:bookmark, user: user, bookmarkable: content_item) }

    context "when not signed in" do
      it "redirects to sign in" do
        delete bookmark_path(bookmark)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "destroys the bookmark" do
        expect {
          delete bookmark_path(bookmark)
        }.to change(Bookmark, :count).by(-1)
      end

      it "does not allow deleting other users bookmarks" do
        other_user = create(:user)
        other_item = create(:content_item, :published, site: site, source: source)
        other_bookmark = create(:bookmark, user: other_user, bookmarkable: other_item)

        delete bookmark_path(other_bookmark)

        # Returns 404 because we scope to current_user's bookmarks
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
