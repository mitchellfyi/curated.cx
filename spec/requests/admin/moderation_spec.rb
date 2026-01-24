# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Moderation", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site, tenant: tenant) }
  let(:content_item) { create(:content_item, :published, site: site, source: source) }
  let(:admin) { create(:user, admin: true) }
  let(:owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }
  let(:tenant_admin) { create(:user).tap { |u| u.add_role(:admin, tenant) } }
  let(:editor) { create(:user).tap { |u| u.add_role(:editor, tenant) } }
  let(:user) { create(:user) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "POST /admin/content_items/:content_item_id/hide" do
    context "when user is global admin" do
      before { sign_in admin }

      it "hides the content item" do
        post hide_admin_content_item_path(content_item), as: :json

        expect(response).to have_http_status(:success)
        expect(content_item.reload.hidden?).to be true
      end

      it "sets hidden_at timestamp" do
        freeze_time do
          post hide_admin_content_item_path(content_item), as: :json

          expect(content_item.reload.hidden_at).to eq(Time.current)
        end
      end

      it "sets hidden_by to current user" do
        post hide_admin_content_item_path(content_item), as: :json

        expect(content_item.reload.hidden_by).to eq(admin)
      end

      it "returns hidden status in json" do
        post hide_admin_content_item_path(content_item), as: :json

        json = JSON.parse(response.body)
        expect(json["hidden"]).to be true
      end
    end

    context "when user is tenant owner" do
      before { sign_in owner }

      it "hides the content item" do
        post hide_admin_content_item_path(content_item), as: :json

        expect(response).to have_http_status(:success)
        expect(content_item.reload.hidden?).to be true
      end
    end

    context "when user is tenant admin" do
      before { sign_in tenant_admin }

      it "hides the content item" do
        post hide_admin_content_item_path(content_item), as: :json

        expect(response).to have_http_status(:success)
        expect(content_item.reload.hidden?).to be true
      end
    end

    context "when user is editor" do
      before { sign_in editor }

      it "returns forbidden" do
        post hide_admin_content_item_path(content_item), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when user is regular user" do
      before { sign_in user }

      it "redirects to root" do
        post hide_admin_content_item_path(content_item)

        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        post hide_admin_content_item_path(content_item)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /admin/content_items/:content_item_id/unhide" do
    let(:hidden_content_item) { create(:content_item, :hidden, site: site, source: source) }

    context "when user is admin" do
      before { sign_in admin }

      it "unhides the content item" do
        post unhide_admin_content_item_path(hidden_content_item), as: :json

        expect(response).to have_http_status(:success)
        expect(hidden_content_item.reload.hidden?).to be false
      end

      it "clears hidden_at timestamp" do
        post unhide_admin_content_item_path(hidden_content_item), as: :json

        expect(hidden_content_item.reload.hidden_at).to be_nil
      end

      it "clears hidden_by" do
        post unhide_admin_content_item_path(hidden_content_item), as: :json

        expect(hidden_content_item.reload.hidden_by).to be_nil
      end

      it "returns hidden false in json" do
        post unhide_admin_content_item_path(hidden_content_item), as: :json

        json = JSON.parse(response.body)
        expect(json["hidden"]).to be false
      end
    end

    context "when user is tenant owner" do
      before { sign_in owner }

      it "unhides the content item" do
        post unhide_admin_content_item_path(hidden_content_item), as: :json

        expect(response).to have_http_status(:success)
        expect(hidden_content_item.reload.hidden?).to be false
      end
    end

    context "when user is editor" do
      before { sign_in editor }

      it "returns forbidden" do
        post unhide_admin_content_item_path(hidden_content_item), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /admin/content_items/:content_item_id/lock_comments" do
    context "when user is admin" do
      before { sign_in admin }

      it "locks comments on the content item" do
        post lock_comments_admin_content_item_path(content_item), as: :json

        expect(response).to have_http_status(:success)
        expect(content_item.reload.comments_locked?).to be true
      end

      it "sets comments_locked_at timestamp" do
        freeze_time do
          post lock_comments_admin_content_item_path(content_item), as: :json

          expect(content_item.reload.comments_locked_at).to eq(Time.current)
        end
      end

      it "sets comments_locked_by to current user" do
        post lock_comments_admin_content_item_path(content_item), as: :json

        expect(content_item.reload.comments_locked_by).to eq(admin)
      end

      it "returns comments_locked true in json" do
        post lock_comments_admin_content_item_path(content_item), as: :json

        json = JSON.parse(response.body)
        expect(json["comments_locked"]).to be true
      end
    end

    context "when user is tenant owner" do
      before { sign_in owner }

      it "locks comments on the content item" do
        post lock_comments_admin_content_item_path(content_item), as: :json

        expect(response).to have_http_status(:success)
        expect(content_item.reload.comments_locked?).to be true
      end
    end

    context "when user is editor" do
      before { sign_in editor }

      it "returns forbidden" do
        post lock_comments_admin_content_item_path(content_item), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /admin/content_items/:content_item_id/unlock_comments" do
    let(:locked_content_item) { create(:content_item, :comments_locked, site: site, source: source) }

    context "when user is admin" do
      before { sign_in admin }

      it "unlocks comments on the content item" do
        post unlock_comments_admin_content_item_path(locked_content_item), as: :json

        expect(response).to have_http_status(:success)
        expect(locked_content_item.reload.comments_locked?).to be false
      end

      it "clears comments_locked_at timestamp" do
        post unlock_comments_admin_content_item_path(locked_content_item), as: :json

        expect(locked_content_item.reload.comments_locked_at).to be_nil
      end

      it "clears comments_locked_by" do
        post unlock_comments_admin_content_item_path(locked_content_item), as: :json

        expect(locked_content_item.reload.comments_locked_by).to be_nil
      end

      it "returns comments_locked false in json" do
        post unlock_comments_admin_content_item_path(locked_content_item), as: :json

        json = JSON.parse(response.body)
        expect(json["comments_locked"]).to be false
      end
    end

    context "when user is tenant owner" do
      before { sign_in owner }

      it "unlocks comments on the content item" do
        post unlock_comments_admin_content_item_path(locked_content_item), as: :json

        expect(response).to have_http_status(:success)
        expect(locked_content_item.reload.comments_locked?).to be false
      end
    end

    context "when user is editor" do
      before { sign_in editor }

      it "returns forbidden" do
        post unlock_comments_admin_content_item_path(locked_content_item), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "html format" do
    before { sign_in admin }

    it "redirects on hide" do
      post hide_admin_content_item_path(content_item)

      expect(response).to redirect_to(admin_root_path)
    end

    it "redirects on unhide" do
      hidden_content_item = create(:content_item, :hidden, site: site, source: source)
      post unhide_admin_content_item_path(hidden_content_item)

      expect(response).to redirect_to(admin_root_path)
    end

    it "redirects on lock_comments" do
      post lock_comments_admin_content_item_path(content_item)

      expect(response).to redirect_to(admin_root_path)
    end

    it "redirects on unlock_comments" do
      locked_content_item = create(:content_item, :comments_locked, site: site, source: source)
      post unlock_comments_admin_content_item_path(locked_content_item)

      expect(response).to redirect_to(admin_root_path)
    end
  end

  describe "turbo_stream format" do
    before { sign_in admin }

    it "responds with turbo stream on hide" do
      post hide_admin_content_item_path(content_item), as: :turbo_stream

      expect(response.content_type).to include("text/vnd.turbo-stream.html")
    end
  end

  describe "site isolation" do
    let!(:other_content_item) do
      ActsAsTenant.without_tenant do
        other_tenant = create(:tenant, :enabled)
        other_site = other_tenant.sites.first
        other_source = create(:source, site: other_site, tenant: other_tenant)
        create(:content_item, :published, site: other_site, source: other_source)
      end
    end

    before { sign_in admin }

    it "cannot hide content from other sites" do
      post hide_admin_content_item_path(other_content_item), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
