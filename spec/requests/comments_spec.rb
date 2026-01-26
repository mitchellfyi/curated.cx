# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Comments", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:content_item) { create(:content_item, :published, site: site, source: source) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, admin: true) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /content_items/:content_item_id/comments" do
    let!(:comments) { create_list(:comment, 3, content_item: content_item, site: site) }

    it "returns http success" do
      get content_item_comments_path(content_item)

      expect(response).to have_http_status(:success)
    end

    it "returns comments for the content item" do
      get content_item_comments_path(content_item)

      expect(assigns(:comments)).to match_array(comments)
    end

    context "when user is not authenticated" do
      it "still allows viewing comments" do
        get content_item_comments_path(content_item)

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /content_items/:content_item_id/comments/:id" do
    let(:comment) { create(:comment, content_item: content_item, site: site, user: user) }

    it "returns http success" do
      get content_item_comment_path(content_item, comment)

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /content_items/:content_item_id/comments" do
    let(:valid_params) { { comment: { body: "This is a test comment" } } }

    context "when user is authenticated" do
      before { sign_in user }

      context "with valid params" do
        it "creates a new comment" do
          expect {
            post content_item_comments_path(content_item), params: valid_params, as: :json
          }.to change(Comment, :count).by(1)
        end

        it "returns created status" do
          post content_item_comments_path(content_item), params: valid_params, as: :json

          expect(response).to have_http_status(:created)
        end

        it "increments comments_count" do
          expect {
            post content_item_comments_path(content_item), params: valid_params, as: :json
          }.to change { content_item.reload.comments_count }.by(1)
        end

        it "assigns comment to current user" do
          post content_item_comments_path(content_item), params: valid_params, as: :json

          expect(Comment.last.user).to eq(user)
        end

        it "assigns comment to current site" do
          post content_item_comments_path(content_item), params: valid_params, as: :json

          expect(Comment.last.site).to eq(site)
        end
      end

      context "with parent_id for replies" do
        let(:parent_comment) { create(:comment, content_item: content_item, site: site, user: create(:user)) }

        it "creates a reply" do
          reply_params = { comment: { body: "This is a reply", parent_id: parent_comment.id } }

          post content_item_comments_path(content_item), params: reply_params, as: :json

          comment = Comment.last
          expect(comment.parent).to eq(parent_comment)
          expect(comment.reply?).to be true
        end
      end

      context "with invalid params" do
        let(:invalid_params) { { comment: { body: "" } } }

        it "returns unprocessable entity" do
          post content_item_comments_path(content_item), params: invalid_params, as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns error messages" do
          post content_item_comments_path(content_item), params: invalid_params, as: :json

          json = JSON.parse(response.body)
          expect(json["errors"]).to be_present
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        it "returns forbidden status" do
          post content_item_comments_path(content_item), params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a comment" do
          expect {
            post content_item_comments_path(content_item), params: valid_params, as: :json
          }.not_to change(Comment, :count)
        end
      end

      context "when comments are locked" do
        let(:locked_content_item) { create(:content_item, :comments_locked, site: site, source: source) }

        it "returns forbidden status" do
          post content_item_comments_path(locked_content_item), params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a comment" do
          expect {
            post content_item_comments_path(locked_content_item), params: valid_params, as: :json
          }.not_to change(Comment, :count)
        end
      end

      context "rate limiting" do
        # Use memory store for rate limiting tests since test env uses null_store
        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
          Rails.cache = original_cache
        end

        it "allows comments within rate limit" do
          post content_item_comments_path(content_item), params: valid_params, as: :json
          expect(response).to have_http_status(:created)
        end

        it "returns too_many_requests after exceeding limit" do
          # Simulate hitting the rate limit by pre-filling the cache
          key = "rate_limit:#{site.id}:#{user.id}:comment:#{Time.current.beginning_of_hour.to_i}"
          Rails.cache.write(key, 10, expires_in: 1.hour)

          post content_item_comments_path(content_item), params: valid_params, as: :json
          expect(response).to have_http_status(:too_many_requests)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post content_item_comments_path(content_item), params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /content_items/:content_item_id/comments/:id" do
    let!(:comment) { create(:comment, content_item: content_item, site: site, user: user) }
    let(:update_params) { { comment: { body: "Updated comment body" } } }

    context "when user is authenticated" do
      before { sign_in user }

      context "when user is the comment author" do
        it "updates the comment" do
          patch content_item_comment_path(content_item, comment), params: update_params, as: :json

          expect(response).to have_http_status(:success)
          expect(comment.reload.body).to eq("Updated comment body")
        end

        it "marks comment as edited" do
          expect {
            patch content_item_comment_path(content_item, comment), params: update_params, as: :json
          }.to change { comment.reload.edited_at }.from(nil)
        end
      end

      context "when user is not the comment author" do
        let(:other_user) { create(:user) }
        before { sign_in other_user }

        it "returns forbidden" do
          patch content_item_comment_path(content_item, comment), params: update_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        it "returns forbidden status" do
          patch content_item_comment_path(content_item, comment), params: update_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        patch content_item_comment_path(content_item, comment), params: update_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /content_items/:content_item_id/comments/:id" do
    let!(:comment) { create(:comment, content_item: content_item, site: site, user: user) }

    context "when user is global admin" do
      before { sign_in admin }

      it "destroys the comment" do
        expect {
          delete content_item_comment_path(content_item, comment), as: :json
        }.to change(Comment, :count).by(-1)
      end

      it "returns no content" do
        delete content_item_comment_path(content_item, comment), as: :json

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when user has tenant admin role" do
      let(:tenant_admin) { create(:user) }

      before do
        tenant_admin.add_role(:admin, tenant)
        sign_in tenant_admin
      end

      it "destroys the comment" do
        expect {
          delete content_item_comment_path(content_item, comment), as: :json
        }.to change(Comment, :count).by(-1)
      end
    end

    context "when user is comment author but not admin" do
      before { sign_in user }

      it "returns forbidden (authors cannot delete)" do
        delete content_item_comment_path(content_item, comment), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        delete content_item_comment_path(content_item, comment)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "site isolation" do
    let(:other_tenant) { create(:tenant, :enabled) }
    let(:other_site) { other_tenant.sites.first || create(:site, tenant: other_tenant) }
    let(:other_source) { create(:source, site: other_site) }
    let(:other_content_item) { create(:content_item, :published, site: other_site, source: other_source) }

    before { sign_in user }

    it "only creates comments for current site" do
      post content_item_comments_path(content_item),
           params: { comment: { body: "Test" } },
           as: :json

      comment = Comment.last
      expect(comment.site).to eq(site)
    end

    it "only shows comments from current site" do
      create(:comment, content_item: content_item, site: site, user: user)

      # Create comment in other site
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      create(:comment, content_item: other_content_item, site: other_site, user: user)

      # Switch back
      host! tenant.hostname
      setup_tenant_context(tenant)

      get content_item_comments_path(content_item)

      expect(assigns(:comments).count).to eq(1)
    end
  end
end
