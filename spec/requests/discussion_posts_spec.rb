# frozen_string_literal: true

require "rails_helper"

RSpec.describe "DiscussionPosts", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, admin: true) }

  # Use Current.site which is set by setup_tenant_context
  def site
    Current.site
  end

  # Discussion needs to be lazily created after setup_tenant_context sets Current.site
  let(:discussion) { create(:discussion, site: site, user: user) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    # Enable discussions for the site
    Current.site.update!(config: Current.site.config.merge("discussions" => { "enabled" => true }))
  end

  describe "POST /discussions/:discussion_id/posts" do
    let(:valid_params) { { discussion_post: { body: "This is a test post" } } }

    context "when user is authenticated" do
      before { sign_in user }

      context "with valid params" do
        it "creates a new post" do
          expect {
            post discussion_posts_path(discussion), params: valid_params, as: :json
          }.to change(DiscussionPost, :count).by(1)
        end

        it "returns created status" do
          post discussion_posts_path(discussion), params: valid_params, as: :json

          expect(response).to have_http_status(:created)
        end

        it "increments posts_count" do
          expect {
            post discussion_posts_path(discussion), params: valid_params, as: :json
          }.to change { discussion.reload.posts_count }.by(1)
        end

        it "assigns post to current user" do
          post discussion_posts_path(discussion), params: valid_params, as: :json

          expect(DiscussionPost.last.user).to eq(user)
        end

        it "assigns post to current site" do
          post discussion_posts_path(discussion), params: valid_params, as: :json

          expect(DiscussionPost.last.site).to eq(site)
        end

        it "updates discussion last_post_at" do
          freeze_time do
            post discussion_posts_path(discussion), params: valid_params, as: :json

            expect(discussion.reload.last_post_at).to eq(Time.current)
          end
        end
      end

      context "with parent_id for replies" do
        let(:parent_post) { create(:discussion_post, discussion: discussion, user: create(:user), site: site) }

        it "creates a reply" do
          reply_params = { discussion_post: { body: "This is a reply", parent_id: parent_post.id } }

          post discussion_posts_path(discussion), params: reply_params, as: :json

          post_record = DiscussionPost.last
          expect(post_record.parent).to eq(parent_post)
          expect(post_record.reply?).to be true
        end
      end

      context "with invalid params" do
        let(:invalid_params) { { discussion_post: { body: "" } } }

        it "returns unprocessable entity" do
          post discussion_posts_path(discussion), params: invalid_params, as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns error messages" do
          post discussion_posts_path(discussion), params: invalid_params, as: :json

          json = JSON.parse(response.body)
          expect(json["errors"]).to be_present
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        it "returns forbidden status" do
          post discussion_posts_path(discussion), params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a post" do
          expect {
            post discussion_posts_path(discussion), params: valid_params, as: :json
          }.not_to change(DiscussionPost, :count)
        end
      end

      context "when discussion is locked" do
        let(:locked_discussion) { create(:discussion, :locked, site: site, user: user) }

        it "returns forbidden status" do
          post discussion_posts_path(locked_discussion), params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a post" do
          expect {
            post discussion_posts_path(locked_discussion), params: valid_params, as: :json
          }.not_to change(DiscussionPost, :count)
        end
      end

      context "rate limiting" do
        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
          Rails.cache = original_cache
        end

        it "allows posts within rate limit" do
          post discussion_posts_path(discussion), params: valid_params, as: :json
          expect(response).to have_http_status(:created)
        end

        it "returns too_many_requests after exceeding limit" do
          key = "rate_limit:#{site.id}:#{user.id}:discussion_post:#{Time.current.beginning_of_hour.to_i}"
          Rails.cache.write(key, 20, expires_in: 1.hour)

          post discussion_posts_path(discussion), params: valid_params, as: :json
          expect(response).to have_http_status(:too_many_requests)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post discussion_posts_path(discussion), params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /discussions/:discussion_id/posts/:id" do
    let!(:post_record) { create(:discussion_post, discussion: discussion, user: user, site: site) }
    let(:update_params) { { discussion_post: { body: "Updated post body" } } }

    context "when user is authenticated" do
      before { sign_in user }

      context "when user is the post author" do
        it "updates the post" do
          patch discussion_post_path(discussion, post_record), params: update_params, as: :json

          expect(response).to have_http_status(:success)
          expect(post_record.reload.body).to eq("Updated post body")
        end

        it "marks post as edited" do
          expect {
            patch discussion_post_path(discussion, post_record), params: update_params, as: :json
          }.to change { post_record.reload.edited_at }.from(nil)
        end
      end

      context "when user is not the post author" do
        let(:other_user) { create(:user) }
        before { sign_in other_user }

        it "returns forbidden" do
          patch discussion_post_path(discussion, post_record), params: update_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        it "returns forbidden status" do
          patch discussion_post_path(discussion, post_record), params: update_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        patch discussion_post_path(discussion, post_record), params: update_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /discussions/:discussion_id/posts/:id" do
    let!(:post_record) { create(:discussion_post, discussion: discussion, user: user, site: site) }

    context "when user is the post author" do
      before { sign_in user }

      it "destroys the post" do
        expect {
          delete discussion_post_path(discussion, post_record), as: :json
        }.to change(DiscussionPost, :count).by(-1)
      end

      it "returns no content" do
        delete discussion_post_path(discussion, post_record), as: :json

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when user is global admin" do
      before { sign_in admin }

      it "destroys the post" do
        expect {
          delete discussion_post_path(discussion, post_record), as: :json
        }.to change(DiscussionPost, :count).by(-1)
      end
    end

    context "when user has tenant admin role" do
      let(:tenant_admin) { create(:user) }

      before do
        tenant_admin.add_role(:admin, tenant)
        sign_in tenant_admin
      end

      it "destroys the post" do
        expect {
          delete discussion_post_path(discussion, post_record), as: :json
        }.to change(DiscussionPost, :count).by(-1)
      end
    end

    context "when user is neither author nor admin" do
      let(:other_user) { create(:user) }
      before { sign_in other_user }

      it "returns forbidden" do
        delete discussion_post_path(discussion, post_record), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        delete discussion_post_path(discussion, post_record)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "site isolation" do
    let(:other_tenant) { create(:tenant, :enabled) }

    before { sign_in user }

    it "only creates posts for current site" do
      current_site = site # Capture current site

      post discussion_posts_path(discussion),
           params: { discussion_post: { body: "Test" } },
           as: :json

      post_record = DiscussionPost.last
      expect(post_record.site).to eq(current_site)
    end

    it "cannot access discussions from other sites" do
      # Create discussion in other site
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      Current.site.update!(config: Current.site.config.merge("discussions" => { "enabled" => true }))
      other_site = Current.site
      other_discussion = create(:discussion, site: other_site, user: user)

      # Switch back to original tenant
      host! tenant.hostname
      setup_tenant_context(tenant)

      # Site scoping should prevent access to the other discussion
      # The request won't raise an error but should return 404
      post "/discussions/#{other_discussion.id}/posts",
           params: { discussion_post: { body: "Test" } },
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
