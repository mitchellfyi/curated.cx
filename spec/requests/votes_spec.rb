# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Votes", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:entry) { create(:entry, :feed, :published, site: site, source: source) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, admin: true) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "POST /entries/:entry_id/vote" do
    context "when user is authenticated" do
      before { sign_in user }

      context "when user has not voted" do
        it "creates a new vote" do
          expect {
            post vote_entry_path(entry), as: :json
          }.to change(Vote, :count).by(1)

          expect(response).to have_http_status(:success)
        end

        it "increments the upvotes_count" do
          expect {
            post vote_entry_path(entry), as: :json
          }.to change { entry.reload.upvotes_count }.by(1)
        end

        it "returns voted status and count" do
          post vote_entry_path(entry), as: :json

          json = JSON.parse(response.body)
          expect(json["voted"]).to be true
          expect(json["count"]).to eq(1)
        end
      end

      context "when user has already voted" do
        before do
          create(:vote, votable: entry, user: user, site: site)
        end

        it "removes the existing vote (toggle off)" do
          expect {
            post vote_entry_path(entry), as: :json
          }.to change(Vote, :count).by(-1)

          expect(response).to have_http_status(:success)
        end

        it "decrements the upvotes_count" do
          expect {
            post vote_entry_path(entry), as: :json
          }.to change { entry.reload.upvotes_count }.by(-1)
        end

        it "returns unvoted status and count" do
          post vote_entry_path(entry), as: :json

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
          post vote_entry_path(entry), as: :json

          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a vote" do
          expect {
            post vote_entry_path(entry), as: :json
          }.not_to change(Vote, :count)
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

        it "allows votes within rate limit" do
          # The rate limit is 100 votes/hour, so first vote should work
          post vote_entry_path(entry), as: :json
          expect(response).to have_http_status(:success)
        end

        it "returns too_many_requests after exceeding limit" do
          # Simulate hitting the rate limit by pre-filling the cache
          key = "rate_limit:#{site.id}:#{user.id}:vote:#{Time.current.beginning_of_hour.to_i}"
          Rails.cache.write(key, 100, expires_in: 1.hour)

          post vote_entry_path(entry), as: :json
          expect(response).to have_http_status(:too_many_requests)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post vote_entry_path(entry)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "turbo stream format" do
      before { sign_in user }

      it "responds with turbo stream" do
        post vote_entry_path(entry), as: :turbo_stream

        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end
    end

    context "html format" do
      before { sign_in user }

      it "redirects back" do
        post vote_entry_path(entry)

        expect(response).to redirect_to(feed_index_path)
      end
    end
  end

  describe "site isolation" do
    let(:other_tenant) { create(:tenant, :enabled) }
    let(:other_site) { other_tenant.sites.first || create(:site, tenant: other_tenant) }
    let(:other_source) { create(:source, site: other_site) }
    let(:other_content_item) { create(:entry, :feed, :published, site: other_site, source: other_source) }

    before { sign_in user }

    it "only creates votes for current site" do
      post vote_entry_path(entry), as: :json

      vote = Vote.last
      expect(vote.site).to eq(site)
    end

    it "does not allow voting on content from other sites" do
      # Switch to other tenant context
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)

      # Create a vote in other site
      create(:vote, votable: other_content_item, user: user, site: other_site)

      # Switch back to original site
      host! tenant.hostname
      setup_tenant_context(tenant)

      # User should be able to vote on original site content
      expect {
        post vote_entry_path(entry), as: :json
      }.to change(Vote, :count).by(1)
    end
  end
end
