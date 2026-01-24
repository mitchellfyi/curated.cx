# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Flags", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:content_item) { create(:content_item, :published, site: site, source: source) }
  let(:user) { create(:user) }
  let(:content_owner) { create(:user) }
  let(:admin) { create(:user, admin: true) }
  let(:comment) { create(:comment, content_item: content_item, user: content_owner, site: site) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "POST /flags" do
    context "when user is authenticated" do
      before { sign_in user }

      context "flagging a content item" do
        let(:valid_params) do
          {
            flaggable_type: "ContentItem",
            flaggable_id: content_item.id,
            flag: { reason: "spam", details: "This is spam content" }
          }
        end

        it "creates a new flag" do
          expect {
            post flags_path, params: valid_params, as: :json
          }.to change(Flag, :count).by(1)

          expect(response).to have_http_status(:created)
        end

        it "creates a flag with correct attributes" do
          post flags_path, params: valid_params, as: :json

          flag = Flag.last
          expect(flag.user).to eq(user)
          expect(flag.flaggable).to eq(content_item)
          expect(flag.site).to eq(site)
          expect(flag.reason).to eq("spam")
          expect(flag.details).to eq("This is spam content")
        end

        it "returns success message" do
          post flags_path, params: valid_params, as: :json

          json = JSON.parse(response.body)
          expect(json["success"]).to be true
          expect(json["message"]).to eq(I18n.t("flags.created"))
        end

        it "enqueues admin notification email" do
          expect {
            post flags_path, params: valid_params, as: :json
          }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
        end
      end

      context "flagging a comment" do
        let(:valid_params) do
          {
            flaggable_type: "Comment",
            flaggable_id: comment.id,
            flag: { reason: "harassment" }
          }
        end

        it "creates a new flag for the comment" do
          expect {
            post flags_path, params: valid_params, as: :json
          }.to change(Flag, :count).by(1)

          flag = Flag.last
          expect(flag.flaggable).to eq(comment)
          expect(flag.reason).to eq("harassment")
        end
      end

      context "when flagging own comment" do
        let(:own_comment) { create(:comment, content_item: content_item, user: user, site: site) }
        let(:invalid_params) do
          {
            flaggable_type: "Comment",
            flaggable_id: own_comment.id,
            flag: { reason: "spam" }
          }
        end

        it "does not create a flag" do
          expect {
            post flags_path, params: invalid_params, as: :json
          }.not_to change(Flag, :count)
        end

        it "returns forbidden status due to policy" do
          post flags_path, params: invalid_params, as: :json

          # Policy denies flagging own content with 403 Forbidden
          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when already flagged" do
        before do
          create(:flag, flaggable: content_item, user: user, site: site)
        end

        let(:duplicate_params) do
          {
            flaggable_type: "ContentItem",
            flaggable_id: content_item.id,
            flag: { reason: "spam" }
          }
        end

        it "does not create a duplicate flag" do
          expect {
            post flags_path, params: duplicate_params, as: :json
          }.not_to change(Flag, :count)
        end

        it "returns unprocessable entity status" do
          post flags_path, params: duplicate_params, as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        let(:valid_params) do
          {
            flaggable_type: "ContentItem",
            flaggable_id: content_item.id,
            flag: { reason: "spam" }
          }
        end

        it "returns forbidden status" do
          post flags_path, params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a flag" do
          expect {
            post flags_path, params: valid_params, as: :json
          }.not_to change(Flag, :count)
        end
      end

      context "rate limiting" do
        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
          Rails.cache = original_cache
        end

        let(:valid_params) do
          {
            flaggable_type: "ContentItem",
            flaggable_id: content_item.id,
            flag: { reason: "spam" }
          }
        end

        it "allows flags within rate limit" do
          post flags_path, params: valid_params, as: :json
          expect(response).to have_http_status(:created)
        end

        it "returns too_many_requests after exceeding limit" do
          # Pre-fill the cache to simulate hitting rate limit (20/hour)
          key = "rate_limit:#{site.id}:#{user.id}:flag:#{Time.current.beginning_of_hour.to_i}"
          Rails.cache.write(key, 20, expires_in: 1.hour)

          post flags_path, params: valid_params, as: :json
          expect(response).to have_http_status(:too_many_requests)
        end
      end

      context "with invalid flaggable type" do
        let(:invalid_params) do
          {
            flaggable_type: "User",
            flaggable_id: user.id,
            flag: { reason: "spam" }
          }
        end

        it "returns not found status" do
          post flags_path, params: invalid_params, as: :json

          # Controller returns 404 for invalid flaggable types
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with non-existent flaggable" do
        let(:invalid_params) do
          {
            flaggable_type: "ContentItem",
            flaggable_id: 99999,
            flag: { reason: "spam" }
          }
        end

        it "returns not found status" do
          post flags_path, params: invalid_params, as: :json

          # Controller returns 404 for non-existent flaggables
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when user is not authenticated" do
      let(:valid_params) do
        {
          flaggable_type: "ContentItem",
          flaggable_id: content_item.id,
          flag: { reason: "spam" }
        }
      end

      it "redirects to sign in" do
        post flags_path, params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "turbo stream format" do
      before { sign_in user }

      let(:valid_params) do
        {
          flaggable_type: "ContentItem",
          flaggable_id: content_item.id,
          flag: { reason: "spam" }
        }
      end

      it "responds with turbo stream" do
        post flags_path, params: valid_params, as: :turbo_stream

        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end
    end

    context "html format" do
      before { sign_in user }

      let(:valid_params) do
        {
          flaggable_type: "ContentItem",
          flaggable_id: content_item.id,
          flag: { reason: "spam" }
        }
      end

      it "redirects back with notice" do
        post flags_path, params: valid_params

        expect(response).to redirect_to(feed_index_path)
        expect(flash[:notice]).to eq(I18n.t("flags.created"))
      end
    end
  end

  describe "site isolation" do
    before { sign_in user }

    it "only creates flags for current site" do
      params = {
        flaggable_type: "ContentItem",
        flaggable_id: content_item.id,
        flag: { reason: "spam" }
      }

      post flags_path, params: params, as: :json

      flag = Flag.last
      expect(flag.site).to eq(site)
    end

    it "does not allow flagging content from other sites" do
      # Create other tenant's content in their context
      other_tenant = create(:tenant, :enabled)
      other_site = nil
      other_content_item = nil

      ActsAsTenant.with_tenant(other_tenant) do
        other_site = other_tenant.sites.first || create(:site, tenant: other_tenant)
        other_source = create(:source, site: other_site)
        other_content_item = create(:content_item, :published, site: other_site, source: other_source)
      end

      # Attempt to flag content from a different site while in our site context
      # This should fail because the content_item can't be found in current site scope
      params = {
        flaggable_type: "ContentItem",
        flaggable_id: other_content_item.id,
        flag: { reason: "spam" }
      }

      post flags_path, params: params, as: :json

      # Controller returns 404 for content not found in current site
      expect(response).to have_http_status(:not_found)
    end
  end
end
