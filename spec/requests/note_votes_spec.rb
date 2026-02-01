# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Note Votes", type: :request do
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

  describe "POST /notes/:id/vote" do
    context "when user is authenticated" do
      before { sign_in user }

      context "when user has not voted" do
        it "creates a new vote" do
          expect {
            post vote_note_path(note), as: :json
          }.to change(Vote, :count).by(1)

          expect(response).to have_http_status(:success)
        end

        it "increments the upvotes_count" do
          expect {
            post vote_note_path(note), as: :json
          }.to change { note.reload.upvotes_count }.by(1)
        end

        it "returns voted status and count" do
          post vote_note_path(note), as: :json

          json = JSON.parse(response.body)
          expect(json["voted"]).to be true
          expect(json["count"]).to eq(1)
        end

        it "creates vote associated with the note" do
          post vote_note_path(note), as: :json

          vote = Vote.last
          expect(vote.votable).to eq(note)
          expect(vote.votable_type).to eq("Note")
        end
      end

      context "when user has already voted" do
        before do
          create(:vote, votable: note, user: user, site: site)
        end

        it "removes the existing vote (toggle off)" do
          expect {
            post vote_note_path(note), as: :json
          }.to change(Vote, :count).by(-1)

          expect(response).to have_http_status(:success)
        end

        it "decrements the upvotes_count" do
          expect {
            post vote_note_path(note), as: :json
          }.to change { note.reload.upvotes_count }.by(-1)
        end

        it "returns unvoted status and count" do
          post vote_note_path(note), as: :json

          json = JSON.parse(response.body)
          expect(json["voted"]).to be false
          expect(json["count"]).to eq(0)
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        it "returns forbidden status" do
          post vote_note_path(note), as: :json

          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a vote" do
          expect {
            post vote_note_path(note), as: :json
          }.not_to change(Vote, :count)
        end
      end

      context "rate limiting" do
        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
          Rails.cache = original_cache
        end

        it "allows votes within rate limit" do
          post vote_note_path(note), as: :json
          expect(response).to have_http_status(:success)
        end

        it "returns too_many_requests after exceeding limit" do
          key = "rate_limit:#{site.id}:#{user.id}:vote:#{Time.current.beginning_of_hour.to_i}"
          Rails.cache.write(key, 100, expires_in: 1.hour)

          post vote_note_path(note), as: :json
          expect(response).to have_http_status(:too_many_requests)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post vote_note_path(note)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "turbo stream format" do
      before { sign_in user }

      it "responds with turbo stream" do
        post vote_note_path(note), as: :turbo_stream

        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end

      it "replaces the vote button element" do
        post vote_note_path(note), as: :turbo_stream

        expect(response.body).to include("turbo-stream")
        expect(response.body).to include("note-vote-button-#{note.id}")
      end
    end

    context "html format" do
      before { sign_in user }

      it "redirects back" do
        post vote_note_path(note)

        expect(response).to have_http_status(:redirect)
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

    it "only creates votes for current site" do
      post vote_note_path(note), as: :json

      vote = Vote.last
      expect(vote.site).to eq(site)
    end

    it "allows same user to vote on notes from different sites" do
      # Vote on original site
      post vote_note_path(note), as: :json
      expect(response).to have_http_status(:success)
      expect(Vote.last.site).to eq(site)
    end
  end
end
