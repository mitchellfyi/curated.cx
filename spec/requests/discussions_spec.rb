# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Discussions", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:user) { create(:user) }
  let(:admin) { create(:user, admin: true) }

  # Use Current.site which is set by setup_tenant_context
  def site
    Current.site
  end

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    # Enable discussions for the site
    Current.site.update!(config: Current.site.config.merge("discussions" => { "enabled" => true }))
  end

  describe "GET /discussions" do
    let!(:discussions) { create_list(:discussion, 3, site: site, user: user) }

    it "returns http success" do
      get discussions_path

      expect(response).to have_http_status(:success)
    end

    it "returns discussions for the site" do
      get discussions_path

      expect(assigns(:discussions)).to match_array(discussions)
    end

    context "when user is not authenticated" do
      it "still allows viewing discussions" do
        get discussions_path

        expect(response).to have_http_status(:success)
      end
    end

    context "with pinned discussions" do
      let!(:pinned) { create(:discussion, :pinned, site: site, user: user) }

      it "shows pinned discussions first" do
        get discussions_path

        expect(assigns(:discussions).first).to eq(pinned)
      end
    end

    context "with subscribers_only discussions" do
      let!(:public_discussion) { create(:discussion, site: site, user: user, visibility: :public_access) }
      let!(:subscribers_only) { create(:discussion, :subscribers_only, site: site, user: user) }

      it "shows only public discussions to non-subscribers" do
        get discussions_path

        expect(assigns(:discussions)).to include(public_discussion)
        expect(assigns(:discussions)).not_to include(subscribers_only)
      end

      it "shows all discussions to subscribers" do
        create(:digest_subscription, user: user, site: site, active: true)
        sign_in user

        get discussions_path

        expect(assigns(:discussions)).to include(public_discussion, subscribers_only)
      end
    end
  end

  describe "GET /discussions/:id" do
    let(:discussion) { create(:discussion, site: site, user: user) }

    it "returns http success" do
      get discussion_path(discussion)

      expect(response).to have_http_status(:success)
    end

    context "when discussion is subscribers_only" do
      let(:discussion) { create(:discussion, :subscribers_only, site: site, user: user) }

      it "redirects anonymous users to sign in" do
        get discussion_path(discussion)

        expect(response).to redirect_to(new_user_session_path)
      end

      it "denies access to authenticated non-subscribers" do
        other_user = create(:user)
        sign_in other_user

        get discussion_path(discussion)

        expect(response).to redirect_to(root_path)
      end

      it "allows access to subscribers" do
        create(:digest_subscription, user: user, site: site, active: true)
        sign_in user

        get discussion_path(discussion)

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /discussions/new" do
    context "when user is authenticated" do
      before { sign_in user }

      it "returns http success" do
        get new_discussion_path

        expect(response).to have_http_status(:success)
      end
    end

    context "when discussions are disabled" do
      before do
        site.config["discussions"] = { "enabled" => false }
        site.save!
        sign_in user
      end

      it "redirects with alert" do
        get new_discussion_path

        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        get new_discussion_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /discussions" do
    let(:valid_params) { { discussion: { title: "Test Discussion", body: "This is a test discussion" } } }

    context "when user is authenticated" do
      before { sign_in user }

      context "with valid params" do
        it "creates a new discussion" do
          expect {
            post discussions_path, params: valid_params, as: :json
          }.to change(Discussion, :count).by(1)
        end

        it "returns created status" do
          post discussions_path, params: valid_params, as: :json

          expect(response).to have_http_status(:created)
        end

        it "assigns discussion to current user" do
          post discussions_path, params: valid_params, as: :json

          expect(Discussion.last.user).to eq(user)
        end

        it "assigns discussion to current site" do
          post discussions_path, params: valid_params, as: :json

          expect(Discussion.last.site).to eq(site)
        end
      end

      context "with invalid params" do
        let(:invalid_params) { { discussion: { title: "", body: "Test" } } }

        it "returns unprocessable entity" do
          post discussions_path, params: invalid_params, as: :json

          expect(response).to have_http_status(:unprocessable_content)
        end

        it "returns error messages" do
          post discussions_path, params: invalid_params, as: :json

          json = JSON.parse(response.body)
          expect(json["errors"]).to be_present
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        it "returns forbidden status" do
          post discussions_path, params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end

        it "does not create a discussion" do
          expect {
            post discussions_path, params: valid_params, as: :json
          }.not_to change(Discussion, :count)
        end
      end

      context "when discussions are disabled" do
        before do
          site.config["discussions"] = { "enabled" => false }
          site.save!
        end

        it "returns forbidden status" do
          post discussions_path, params: valid_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end
      end

      context "rate limiting" do
        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
          Rails.cache = original_cache
        end

        it "allows discussions within rate limit" do
          post discussions_path, params: valid_params, as: :json
          expect(response).to have_http_status(:created)
        end

        it "returns too_many_requests after exceeding limit" do
          key = "rate_limit:#{site.id}:#{user.id}:discussion:#{Time.current.beginning_of_hour.to_i}"
          Rails.cache.write(key, 5, expires_in: 1.hour)

          post discussions_path, params: valid_params, as: :json
          expect(response).to have_http_status(:too_many_requests)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post discussions_path, params: valid_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "PATCH /discussions/:id" do
    let!(:discussion) { create(:discussion, site: site, user: user) }
    let(:update_params) { { discussion: { title: "Updated Title", body: "Updated body" } } }

    context "when user is authenticated" do
      before { sign_in user }

      context "when user is the discussion author" do
        it "updates the discussion" do
          patch discussion_path(discussion), params: update_params, as: :json

          expect(response).to have_http_status(:success)
          expect(discussion.reload.title).to eq("Updated Title")
        end
      end

      context "when user is not the discussion author" do
        let(:other_user) { create(:user) }
        before { sign_in other_user }

        it "returns forbidden" do
          patch discussion_path(discussion), params: update_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end
      end

      context "when user is banned" do
        before do
          create(:site_ban, site: site, user: user, banned_by: admin)
        end

        it "returns forbidden status" do
          patch discussion_path(discussion), params: update_params, as: :json

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        patch discussion_path(discussion), params: update_params

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "DELETE /discussions/:id" do
    let!(:discussion) { create(:discussion, site: site, user: user) }

    context "when user is global admin" do
      before { sign_in admin }

      it "destroys the discussion" do
        expect {
          delete discussion_path(discussion), as: :json
        }.to change(Discussion, :count).by(-1)
      end

      it "returns no content" do
        delete discussion_path(discussion), as: :json

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when user has tenant admin role" do
      let(:tenant_admin) { create(:user) }

      before do
        tenant_admin.add_role(:admin, tenant)
        sign_in tenant_admin
      end

      it "destroys the discussion" do
        expect {
          delete discussion_path(discussion), as: :json
        }.to change(Discussion, :count).by(-1)
      end
    end

    context "when user is discussion author but not admin" do
      before { sign_in user }

      it "returns forbidden (authors cannot delete)" do
        delete discussion_path(discussion), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        delete discussion_path(discussion)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "site isolation" do
    let(:other_tenant) { create(:tenant, :enabled) }

    before { sign_in user }

    it "only creates discussions for current site" do
      current_site = site # Capture current site before POST

      post discussions_path,
           params: { discussion: { title: "Test", body: "Test" } },
           as: :json

      discussion = Discussion.last
      expect(discussion.site).to eq(current_site)
    end

    it "only shows discussions from current site" do
      create(:discussion, site: site, user: user)

      # Create discussion in other site
      host! other_tenant.hostname
      setup_tenant_context(other_tenant)
      Current.site.update!(config: Current.site.config.merge("discussions" => { "enabled" => true }))
      other_site = Current.site
      create(:discussion, site: other_site, user: user)

      # Switch back
      host! tenant.hostname
      setup_tenant_context(tenant)

      get discussions_path

      expect(assigns(:discussions).count).to eq(1)
    end
  end
end
