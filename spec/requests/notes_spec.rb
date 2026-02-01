# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Notes", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:editor) { create(:user) }
  let(:admin) { create(:user, admin: true) }
  let(:note_owner) { create(:user) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    editor.add_role(:editor, tenant)
    note_owner.add_role(:editor, tenant)
  end

  describe "GET /notes" do
    let!(:published_notes) { create_list(:note, 3, :published, site: site, user: note_owner) }
    let!(:draft_note) { create(:note, :draft, site: site, user: note_owner) }
    let!(:hidden_note) { create(:note, :published, :hidden, site: site, user: note_owner) }

    it "returns http success" do
      get notes_path
      expect(response).to have_http_status(:success)
    end

    it "returns published notes only" do
      get notes_path
      expect(assigns(:notes)).to match_array(published_notes)
      expect(assigns(:notes)).not_to include(draft_note)
      expect(assigns(:notes)).not_to include(hidden_note)
    end

    context "when user is not authenticated" do
      it "still allows viewing notes" do
        get notes_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /notes/:id" do
    let(:note) { create(:note, :published, site: site, user: note_owner) }

    it "returns http success for published note" do
      get note_path(note)
      expect(response).to have_http_status(:success)
    end

    context "when note is not published" do
      let(:draft_note) { create(:note, :draft, site: site, user: note_owner) }

      it "redirects unauthorized users" do
        get note_path(draft_note)
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when note is hidden" do
      let(:hidden_note) { create(:note, :published, :hidden, site: site, user: note_owner) }

      it "redirects unauthorized users" do
        get note_path(hidden_note)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /notes/new" do
    context "when user is an editor" do
      before { sign_in editor }

      it "returns http success" do
        get new_note_path
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is not an editor" do
      before { sign_in user }

      it "redirects unauthorized users" do
        get new_note_path
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        get new_note_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /notes" do
    let(:valid_params) { { note: { body: "This is a test note" } } }

    context "when user is an editor" do
      before { sign_in editor }

      context "with valid params" do
        it "creates a new note" do
          expect {
            post notes_path, params: valid_params
          }.to change(Note, :count).by(1)
        end

        it "redirects to the created note" do
          post notes_path, params: valid_params
          expect(response).to redirect_to(note_path(Note.last))
        end

        it "assigns note to current user" do
          post notes_path, params: valid_params
          expect(Note.last.user).to eq(editor)
        end

        it "assigns note to current site" do
          post notes_path, params: valid_params
          expect(Note.last.site).to eq(site)
        end

        it "creates note as draft by default" do
          post notes_path, params: valid_params
          expect(Note.last.draft?).to be true
        end
      end

      context "with publish param" do
        it "publishes the note immediately" do
          post notes_path, params: valid_params.merge(publish: "1")
          expect(Note.last.published?).to be true
        end
      end

      context "with invalid params" do
        let(:invalid_params) { { note: { body: "" } } }

        it "returns unprocessable entity" do
          post notes_path, params: invalid_params
          expect(response).to have_http_status(:unprocessable_content)
        end

        it "does not create a note" do
          expect {
            post notes_path, params: invalid_params
          }.not_to change(Note, :count)
        end
      end

      context "when body exceeds max length" do
        let(:long_params) { { note: { body: "a" * (Note::BODY_MAX_LENGTH + 1) } } }

        it "returns unprocessable entity" do
          post notes_path, params: long_params
          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "rate limiting" do
        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
          Rails.cache = original_cache
        end

        it "allows notes within rate limit" do
          post notes_path, params: valid_params
          expect(response).to have_http_status(:redirect)
        end

        it "redirects with alert after exceeding limit" do
          key = "rate_limit:#{site.id}:#{editor.id}:note:#{Time.current.beginning_of_hour.to_i}"
          Rails.cache.write(key, 10, expires_in: 1.hour)

          post notes_path, params: valid_params
          expect(response).to have_http_status(:redirect)
          expect(flash[:alert]).to be_present
        end
      end
    end

    context "when user is not an editor" do
      before { sign_in user }

      it "redirects unauthorized users" do
        post notes_path, params: valid_params
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post notes_path, params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /notes/:id" do
    let!(:note) { create(:note, :published, site: site, user: note_owner) }
    let(:update_params) { { note: { body: "Updated note body" } } }

    context "when user is the note owner" do
      before { sign_in note_owner }

      it "updates the note" do
        patch note_path(note), params: update_params
        expect(response).to redirect_to(note_path(note))
        expect(note.reload.body).to eq("Updated note body")
      end
    end

    context "when user is an admin" do
      before { sign_in admin }

      it "updates any note" do
        patch note_path(note), params: update_params
        expect(response).to redirect_to(note_path(note))
        expect(note.reload.body).to eq("Updated note body")
      end
    end

    context "when user is not the note owner" do
      before { sign_in editor }

      it "redirects unauthorized users" do
        patch note_path(note), params: update_params
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        patch note_path(note), params: update_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /notes/:id" do
    let!(:note) { create(:note, :published, site: site, user: note_owner) }

    context "when user is the note owner" do
      before { sign_in note_owner }

      it "destroys the note" do
        expect {
          delete note_path(note)
        }.to change(Note, :count).by(-1)
      end

      it "redirects to notes index" do
        delete note_path(note)
        expect(response).to redirect_to(notes_path)
      end
    end

    context "when user is an admin" do
      before { sign_in admin }

      it "destroys any note" do
        expect {
          delete note_path(note)
        }.to change(Note, :count).by(-1)
      end
    end

    context "when user is not the note owner" do
      before { sign_in editor }

      it "redirects unauthorized users" do
        delete note_path(note)
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        delete note_path(note)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /notes/:id/repost" do
    let!(:original_note) { create(:note, :published, site: site, user: note_owner) }

    context "when user is an editor" do
      before { sign_in editor }

      it "creates a repost" do
        expect {
          post repost_note_path(original_note)
        }.to change(Note, :count).by(1)
      end

      it "links repost to original note" do
        post repost_note_path(original_note)
        repost = Note.last
        expect(repost.repost_of).to eq(original_note)
      end

      it "copies body from original note" do
        post repost_note_path(original_note)
        repost = Note.last
        expect(repost.body).to eq(original_note.body)
      end

      it "publishes the repost immediately" do
        post repost_note_path(original_note)
        repost = Note.last
        expect(repost.published?).to be true
      end

      it "increments reposts_count on original" do
        expect {
          post repost_note_path(original_note)
        }.to change { original_note.reload.reposts_count }.by(1)
      end

      context "when reposting a repost" do
        let(:first_repost) { create(:note, :published, site: site, user: editor, repost_of: original_note) }

        it "links to the original note, not the intermediate repost" do
          post repost_note_path(first_repost)
          second_repost = Note.last
          expect(second_repost.repost_of).to eq(original_note)
        end
      end

      context "rate limiting" do
        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
          Rails.cache = original_cache
        end

        it "redirects with alert after exceeding limit" do
          key = "rate_limit:#{site.id}:#{editor.id}:note:#{Time.current.beginning_of_hour.to_i}"
          Rails.cache.write(key, 10, expires_in: 1.hour)

          post repost_note_path(original_note)
          expect(response).to have_http_status(:redirect)
          expect(flash[:alert]).to be_present
        end
      end
    end

    context "when user is not an editor" do
      before { sign_in user }

      it "redirects unauthorized users" do
        post repost_note_path(original_note)
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post repost_note_path(original_note)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "site isolation" do
    let(:other_tenant) { create(:tenant, :enabled) }
    let(:other_site) { other_tenant.sites.first || create(:site, tenant: other_tenant) }

    before { sign_in editor }

    it "only creates notes for current site" do
      post notes_path, params: { note: { body: "Test" } }
      expect(Note.last.site).to eq(site)
    end

    it "only shows notes from current site" do
      create(:note, :published, site: site, user: note_owner)

      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      other_editor = create(:user)
      other_editor.add_role(:editor, other_tenant)
      create(:note, :published, site: other_site, user: other_editor)

      host! tenant.hostname
      setup_tenant_context(tenant)

      get notes_path
      expect(assigns(:notes).count).to eq(1)
    end
  end
end
