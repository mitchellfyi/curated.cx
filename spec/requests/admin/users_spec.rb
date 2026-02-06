# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let!(:tenant) { create(:tenant, :ai_news) }
  let(:admin_user) { create(:user, :admin) }
  let(:owner_user) { create(:user) }
  let(:editor_user) { create(:user) }
  let(:target_user) { create(:user) }

  before do
    owner_user.add_role(:owner, tenant)
    editor_user.add_role(:editor, tenant)
  end

  shared_context "tenant context" do
    before do
      host! tenant.hostname
      setup_tenant_context(tenant)
    end
  end

  describe "GET /admin/users" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "renders successfully" do
        get admin_users_path
        expect(response).to have_http_status(:success)
      end

      it "lists users" do
        get admin_users_path
        expect(assigns(:users)).to be_present
      end

      it "supports search" do
        get admin_users_path, params: { search: target_user.email }
        expect(assigns(:users)).to include(target_user)
      end

      it "supports role filter" do
        get admin_users_path, params: { role: "owner" }
        expect(assigns(:users)).to include(owner_user)
        expect(assigns(:users)).not_to include(target_user)
      end

      it "assigns stats" do
        get admin_users_path
        expect(assigns(:stats)).to have_key(:total_users)
        expect(assigns(:stats)).to have_key(:admins)
      end
    end

    context "as owner" do
      before { sign_in owner_user }

      it "renders successfully" do
        get admin_users_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "GET /admin/users/:id" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "renders successfully" do
        get admin_user_path(target_user)
        expect(response).to have_http_status(:success)
      end

      it "shows role management form" do
        get admin_user_path(target_user)
        expect(response.body).to include("Manage Role")
      end
    end
  end

  describe "POST /admin/users/:id/assign_role" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "assigns a role to the user" do
        post assign_role_admin_user_path(target_user), params: { role_name: "editor" }
        expect(response).to redirect_to(admin_user_path(target_user))
        expect(target_user.has_role?(:editor, tenant)).to be true
      end

      it "replaces existing role" do
        target_user.add_role(:viewer, tenant)
        post assign_role_admin_user_path(target_user), params: { role_name: "editor" }
        expect(target_user.has_role?(:editor, tenant)).to be true
        expect(target_user.has_role?(:viewer, tenant)).to be false
      end

      it "rejects invalid role names" do
        post assign_role_admin_user_path(target_user), params: { role_name: "superuser" }
        expect(response).to redirect_to(admin_user_path(target_user))
        expect(flash[:alert]).to include("Invalid role")
      end
    end

    context "as owner" do
      before { sign_in owner_user }

      it "can assign editor role" do
        post assign_role_admin_user_path(target_user), params: { role_name: "editor" }
        expect(target_user.has_role?(:editor, tenant)).to be true
      end

      it "cannot assign owner role (equal to own level)" do
        post assign_role_admin_user_path(target_user), params: { role_name: "owner" }
        expect(flash[:alert]).to include("cannot assign")
      end
    end

    context "as editor" do
      before { sign_in editor_user }

      it "can assign viewer role" do
        post assign_role_admin_user_path(target_user), params: { role_name: "viewer" }
        expect(target_user.has_role?(:viewer, tenant)).to be true
      end

      it "cannot assign editor role (equal to own level)" do
        post assign_role_admin_user_path(target_user), params: { role_name: "editor" }
        expect(flash[:alert]).to include("cannot assign")
      end
    end
  end

  describe "DELETE /admin/users/:id/remove_role" do
    include_context "tenant context"

    context "as admin" do
      before do
        sign_in admin_user
        target_user.add_role(:editor, tenant)
      end

      it "removes the user's tenant roles" do
        delete remove_role_admin_user_path(target_user)
        expect(response).to redirect_to(admin_user_path(target_user))
        expect(target_user.roles.where(resource: tenant)).to be_empty
      end
    end
  end

  describe "POST /admin/users/:id/make_admin" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "grants admin status" do
        post make_admin_admin_user_path(target_user)
        expect(target_user.reload.admin?).to be true
      end
    end

    context "as non-admin" do
      before { sign_in owner_user }

      it "rejects the request" do
        post make_admin_admin_user_path(target_user)
        expect(target_user.reload.admin?).to be false
      end
    end
  end

  describe "POST /admin/users/:id/ban" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "creates a site ban" do
        post ban_admin_user_path(target_user)
        expect(SiteBan.exists?(site: Current.site, user: target_user)).to be true
      end
    end
  end

  describe "POST /admin/users/:id/unban" do
    include_context "tenant context"

    context "as admin" do
      before do
        sign_in admin_user
        SiteBan.create!(site: Current.site, user: target_user, reason: "Test", banned_by: admin_user)
      end

      it "removes the site ban" do
        post unban_admin_user_path(target_user)
        expect(SiteBan.exists?(site: Current.site, user: target_user)).to be false
      end
    end
  end
end
