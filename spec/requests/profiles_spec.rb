# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profiles", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user, display_name: "Test User", bio: "A test bio") }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /profiles/:id" do
    it "returns http success" do
      get profile_path(user)

      expect(response).to have_http_status(:success)
    end

    it "shows user profile information" do
      get profile_path(user)

      expect(response.body).to include(user.profile_name)
    end

    it "shows user's comments from current site" do
      source = create(:source, site: site)
      content_item = create(:content_item, :published, site: site, source: source)
      comment = create(:comment, user: user, content_item: content_item, body: "Test comment")

      get profile_path(user)

      expect(assigns(:comments)).to include(comment)
    end
  end

  describe "GET /profiles/:id/edit" do
    context "when not signed in" do
      it "redirects to sign in" do
        get edit_profile_path(user)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as a different user" do
      let(:other_user) { create(:user) }

      before { sign_in other_user }

      it "denies access" do
        get edit_profile_path(user)

        # Should redirect due to Pundit authorization
        expect(response).to have_http_status(:redirect)
      end
    end

    context "when signed in as the profile owner" do
      before { sign_in user }

      it "returns http success" do
        get edit_profile_path(user)

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "PATCH /profiles/:id" do
    context "when not signed in" do
      it "redirects to sign in" do
        patch profile_path(user), params: { user: { display_name: "New Name" } }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as the profile owner" do
      before { sign_in user }

      it "updates the profile" do
        patch profile_path(user), params: { user: { display_name: "Updated Name", bio: "New bio" } }

        expect(response).to redirect_to(profile_path(user))
        expect(user.reload.display_name).to eq("Updated Name")
        expect(user.reload.bio).to eq("New bio")
      end

      it "validates display_name length" do
        patch profile_path(user), params: { user: { display_name: "a" * 60 } }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "validates bio length" do
        patch profile_path(user), params: { user: { bio: "a" * 600 } }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
