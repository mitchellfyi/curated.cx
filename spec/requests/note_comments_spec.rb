# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Note Comments", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:editor) { create(:user) }
  let(:admin) { create(:user, admin: true) }
  let(:note) { create(:note, :published, site: site, user: editor) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    editor.add_role(:editor, tenant)
  end

  describe "GET /notes/:note_id/comments" do
    let!(:comments) { create_list(:comment, 3, commentable: note, site: site) }

    it "returns http success" do
      get note_comments_path(note)

      expect(response).to have_http_status(:success)
    end

    it "returns comments for the note" do
      get note_comments_path(note)

      expect(assigns(:comments)).to match_array(comments)
    end

    context "when user is not authenticated" do
      it "still allows viewing comments" do
        get note_comments_path(note)

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /notes/:note_id/comments" do
    let(:valid_params) { { comment: { body: "This is a test comment on a note" } } }

    context "when user is authenticated" do
      before { sign_in user }

      context "with valid params" do
        it "creates a new comment" do
          expect {
            post note_comments_path(note), params: valid_params, as: :json
          }.to change(Comment, :count).by(1)
        end

        it "returns created status" do
          post note_comments_path(note), params: valid_params, as: :json

          expect(response).to have_http_status(:created)
        end

        it "increments comments_count on note" do
          expect {
            post note_comments_path(note), params: valid_params, as: :json
          }.to change { note.reload.comments_count }.by(1)
        end

        it "assigns comment to current user" do
          post note_comments_path(note), params: valid_params, as: :json

          expect(Comment.last.user).to eq(user)
        end

        it "assigns comment to current site" do
          post note_comments_path(note), params: valid_params, as: :json

          expect(Comment.last.site).to eq(site)
        end

        it "creates comment associated with the note" do
          post note_comments_path(note), params: valid_params, as: :json

          comment = Comment.last
          expect(comment.commentable).to eq(note)
          expect(comment.commentable_type).to eq("Note")
        end
      end

      context "with parent_id for replies" do
        let(:parent_comment) { create(:comment, commentable: note, site: site, user: create(:user)) }

        it "creates a reply" do
          reply_params = { comment: { body: "This is a reply", parent_id: parent_comment.id } }

          post note_comments_path(note), params: reply_params, as: :json

          comment = Comment.last
          expect(comment.parent).to eq(parent_comment)
          expect(comment.reply?).to be true
        end
      end

      context "with invalid params" do
        let(:invalid_params) { { comment: { body: "" } } }

        it "returns unprocessable entity" do
          post note_comments_path(note), params: invalid_params, as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns error messages" do
          post note_comments_path(note), params: invalid_params, as: :json

          json = JSON.parse(response.body)
          expect(json["errors"]).to be_present
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        it "returns forbidden status" do
          post note_comments_path(note), params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a comment" do
          expect {
            post note_comments_path(note), params: valid_params, as: :json
          }.not_to change(Comment, :count)
        end
      end

      context "rate limiting" do
        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
          Rails.cache = original_cache
        end

        it "allows comments within rate limit" do
          post note_comments_path(note), params: valid_params, as: :json
          expect(response).to have_http_status(:created)
        end

        it "returns too_many_requests after exceeding limit" do
          key = "rate_limit:#{site.id}:#{user.id}:comment:#{Time.current.beginning_of_hour.to_i}"
          Rails.cache.write(key, 10, expires_in: 1.hour)

          post note_comments_path(note), params: valid_params, as: :json
          expect(response).to have_http_status(:too_many_requests)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post note_comments_path(note), params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /notes/:note_id/comments/:id" do
    let!(:comment) { create(:comment, commentable: note, site: site, user: user) }
    let(:update_params) { { comment: { body: "Updated comment body" } } }

    context "when user is authenticated" do
      before { sign_in user }

      context "when user is the comment author" do
        it "updates the comment" do
          patch note_comment_path(note, comment), params: update_params, as: :json

          expect(response).to have_http_status(:success)
          expect(comment.reload.body).to eq("Updated comment body")
        end

        it "marks comment as edited" do
          expect {
            patch note_comment_path(note, comment), params: update_params, as: :json
          }.to change { comment.reload.edited_at }.from(nil)
        end
      end

      context "when user is not the comment author" do
        let(:other_user) { create(:user) }
        before { sign_in other_user }

        it "returns forbidden" do
          patch note_comment_path(note, comment), params: update_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        it "returns forbidden status" do
          patch note_comment_path(note, comment), params: update_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        patch note_comment_path(note, comment), params: update_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /notes/:note_id/comments/:id" do
    let!(:comment) { create(:comment, commentable: note, site: site, user: user) }

    context "when user is global admin" do
      before { sign_in admin }

      it "destroys the comment" do
        expect {
          delete note_comment_path(note, comment), as: :json
        }.to change(Comment, :count).by(-1)
      end

      it "returns no content" do
        delete note_comment_path(note, comment), as: :json

        expect(response).to have_http_status(:no_content)
      end

      it "decrements comments_count on note" do
        expect {
          delete note_comment_path(note, comment), as: :json
        }.to change { note.reload.comments_count }.by(-1)
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
          delete note_comment_path(note, comment), as: :json
        }.to change(Comment, :count).by(-1)
      end
    end

    context "when user is comment author but not admin" do
      before { sign_in user }

      it "returns forbidden (authors cannot delete)" do
        delete note_comment_path(note, comment), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        delete note_comment_path(note, comment)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "site isolation" do
    let(:other_tenant) { create(:tenant, :enabled) }
    let(:other_site) { other_tenant.sites.first || create(:site, tenant: other_tenant) }
    let(:other_editor) { create(:user) }
    let(:other_note) { create(:note, :published, site: other_site, user: other_editor) }

    before do
      sign_in user
      other_editor.add_role(:editor, other_tenant)
    end

    it "only creates comments for current site" do
      post note_comments_path(note),
           params: { comment: { body: "Test" } },
           as: :json

      comment = Comment.last
      expect(comment.site).to eq(site)
    end

    it "only shows comments from the note" do
      create(:comment, commentable: note, site: site, user: user)

      get note_comments_path(note)

      expect(assigns(:comments).count).to eq(1)
    end
  end

  describe "turbo stream responses" do
    before { sign_in user }

    context "on create" do
      it "responds with turbo stream" do
        post note_comments_path(note),
             params: { comment: { body: "Turbo stream comment" } },
             as: :turbo_stream

        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end
    end

    context "on update" do
      let!(:comment) { create(:comment, commentable: note, site: site, user: user) }

      it "responds with turbo stream" do
        patch note_comment_path(note, comment),
              params: { comment: { body: "Updated" } },
              as: :turbo_stream

        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end
    end

    context "on destroy" do
      let!(:comment) { create(:comment, commentable: note, site: site, user: user) }

      before { sign_in admin }

      it "responds with turbo stream" do
        delete note_comment_path(note, comment), as: :turbo_stream

        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end
    end
  end
end
