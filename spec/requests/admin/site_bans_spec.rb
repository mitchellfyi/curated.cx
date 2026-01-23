# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::SiteBans", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin) { create(:user, admin: true) }
  let(:owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }
  let(:tenant_admin) { create(:user).tap { |u| u.add_role(:admin, tenant) } }
  let(:user) { create(:user) }
  let(:banned_user) { create(:user) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /admin/site_bans" do
    context "when user is global admin" do
      before { sign_in admin }

      let!(:site_bans) { create_list(:site_ban, 3, site: site, banned_by: admin) }

      it "returns http success" do
        get admin_site_bans_path

        expect(response).to have_http_status(:success)
      end

      it "assigns site_bans" do
        get admin_site_bans_path

        expect(assigns(:site_bans)).to match_array(site_bans)
      end
    end

    context "when user is tenant owner" do
      before { sign_in owner }

      it "returns http success" do
        get admin_site_bans_path

        expect(response).to have_http_status(:success)
      end
    end

    context "when user is tenant admin" do
      before { sign_in tenant_admin }

      it "returns http success" do
        get admin_site_bans_path

        expect(response).to have_http_status(:success)
      end
    end

    context "when user is regular user" do
      before { sign_in user }

      it "redirects to root" do
        get admin_site_bans_path

        expect(response).to redirect_to(root_path)
      end
    end

    context "when user is not authenticated" do
      it "redirects to sign in" do
        get admin_site_bans_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /admin/site_bans/:id" do
    let!(:site_ban) { create(:site_ban, site: site, user: banned_user, banned_by: admin) }

    context "when user is admin" do
      before { sign_in admin }

      it "returns http success" do
        get admin_site_ban_path(site_ban)

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /admin/site_bans/new" do
    context "when user is admin" do
      before { sign_in admin }

      it "returns http success" do
        get new_admin_site_ban_path

        expect(response).to have_http_status(:success)
      end

      it "assigns a new site_ban" do
        get new_admin_site_ban_path

        expect(assigns(:site_ban)).to be_a_new(SiteBan)
      end
    end
  end

  describe "POST /admin/site_bans" do
    let(:valid_params) do
      {
        site_ban: {
          user_id: banned_user.id,
          reason: "Violation of community guidelines"
        }
      }
    end

    context "when user is admin" do
      before { sign_in admin }

      context "with valid params" do
        it "creates a new site ban" do
          expect {
            post admin_site_bans_path, params: valid_params
          }.to change(SiteBan, :count).by(1)
        end

        it "redirects to site bans index" do
          post admin_site_bans_path, params: valid_params

          expect(response).to redirect_to(admin_site_bans_path)
        end

        it "assigns the site ban to current site" do
          post admin_site_bans_path, params: valid_params

          expect(SiteBan.last.site).to eq(site)
        end

        it "assigns the ban to current user as banned_by" do
          post admin_site_bans_path, params: valid_params

          expect(SiteBan.last.banned_by).to eq(admin)
        end
      end

      context "with expires_at" do
        it "creates a temporary ban" do
          params = valid_params.deep_merge(site_ban: { expires_at: 1.week.from_now })

          post admin_site_bans_path, params: params

          ban = SiteBan.last
          expect(ban.permanent?).to be false
          expect(ban.expires_at).to be_present
        end
      end

      context "with invalid params" do
        let(:invalid_params) { { site_ban: { user_id: nil } } }

        it "returns unprocessable entity" do
          post admin_site_bans_path, params: invalid_params

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "renders new template" do
          post admin_site_bans_path, params: invalid_params

          expect(response).to render_template(:new)
        end
      end

      context "when trying to ban a user twice" do
        before do
          create(:site_ban, site: site, user: banned_user, banned_by: admin)
        end

        it "returns unprocessable entity" do
          post admin_site_bans_path, params: valid_params

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "when trying to ban yourself" do
        let(:self_ban_params) do
          {
            site_ban: {
              user_id: admin.id,
              reason: "Self ban attempt"
            }
          }
        end

        it "returns unprocessable entity" do
          post admin_site_bans_path, params: self_ban_params

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context "when user is regular user" do
      before { sign_in user }

      it "redirects to root" do
        post admin_site_bans_path, params: valid_params

        expect(response).to redirect_to(root_path)
      end

      it "does not create a site ban" do
        expect {
          post admin_site_bans_path, params: valid_params
        }.not_to change(SiteBan, :count)
      end
    end
  end

  describe "DELETE /admin/site_bans/:id" do
    let!(:site_ban) { create(:site_ban, site: site, user: banned_user, banned_by: admin) }

    context "when user is admin" do
      before { sign_in admin }

      it "destroys the site ban" do
        expect {
          delete admin_site_ban_path(site_ban)
        }.to change(SiteBan, :count).by(-1)
      end

      it "redirects to site bans index" do
        delete admin_site_ban_path(site_ban)

        expect(response).to redirect_to(admin_site_bans_path)
      end
    end

    context "when user is tenant admin" do
      before { sign_in tenant_admin }

      it "destroys the site ban" do
        expect {
          delete admin_site_ban_path(site_ban)
        }.to change(SiteBan, :count).by(-1)
      end
    end

    context "when user is regular user" do
      before { sign_in user }

      it "redirects to root" do
        delete admin_site_ban_path(site_ban)

        expect(response).to redirect_to(root_path)
      end

      it "does not destroy the site ban" do
        expect {
          delete admin_site_ban_path(site_ban)
        }.not_to change(SiteBan, :count)
      end
    end
  end

  describe "site isolation" do
    let!(:site_ban) { create(:site_ban, site: site, user: banned_user, banned_by: admin) }
    let(:other_tenant) { create(:tenant, :enabled) }
    let(:other_site) { other_tenant.sites.first || create(:site, tenant: other_tenant) }
    let(:other_user) { create(:user) }

    before do
      # Create a ban in the other site
      Current.site = other_site
      @other_ban = create(:site_ban, site: other_site, user: other_user, banned_by: admin)
      Current.site = site

      sign_in admin
    end

    it "only shows bans from current site" do
      get admin_site_bans_path

      expect(assigns(:site_bans)).to include(site_ban)
      expect(assigns(:site_bans)).not_to include(@other_ban)
    end

    it "cannot access bans from other sites" do
      expect {
        get admin_site_ban_path(@other_ban)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
