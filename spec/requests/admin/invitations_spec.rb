# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Invitations", type: :request do
  let!(:tenant) { create(:tenant, :ai_news) }
  let(:admin_user) { create(:user, :admin) }
  let(:owner_user) { create(:user) }
  let(:editor_user) { create(:user) }

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

  describe "GET /admin/invitations" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "renders successfully" do
        get admin_invitations_path
        expect(response).to have_http_status(:success)
      end

      it "assigns pending and accepted invitations" do
        pending = create(:tenant_invitation, tenant: tenant, invited_by: admin_user)
        accepted = create(:tenant_invitation, :accepted, tenant: tenant, invited_by: admin_user)

        get admin_invitations_path
        expect(assigns(:pending)).to include(pending)
        expect(assigns(:accepted)).to include(accepted)
      end
    end

    context "as owner" do
      before { sign_in owner_user }

      it "renders successfully" do
        get admin_invitations_path
        expect(response).to have_http_status(:success)
      end
    end

    context "as editor" do
      before { sign_in editor_user }

      it "redirects (not admin/owner)" do
        get admin_invitations_path
        expect(response).to redirect_to(admin_root_path)
      end
    end
  end

  describe "POST /admin/invitations" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "creates an invitation" do
        expect {
          post admin_invitations_path, params: { tenant_invitation: { email: "new@example.com", role: "editor" } }
        }.to change(TenantInvitation, :count).by(1)

        expect(response).to redirect_to(admin_invitations_path)
        invitation = TenantInvitation.last
        expect(invitation.email).to eq("new@example.com")
        expect(invitation.role).to eq("editor")
        expect(invitation.tenant).to eq(tenant)
      end

      it "enqueues a mailer" do
        expect {
          post admin_invitations_path, params: { tenant_invitation: { email: "new@example.com", role: "editor" } }
        }.to have_enqueued_mail(TenantInvitationMailer, :invite)
      end

      it "re-renders on invalid params" do
        post admin_invitations_path, params: { tenant_invitation: { email: "", role: "editor" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /admin/invitations/:id" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "destroys the invitation" do
        invitation = create(:tenant_invitation, tenant: tenant, invited_by: admin_user)
        expect {
          delete admin_invitation_path(invitation)
        }.to change(TenantInvitation, :count).by(-1)
      end
    end
  end

  describe "POST /admin/invitations/:id/resend" do
    include_context "tenant context"

    context "as admin" do
      before { sign_in admin_user }

      it "resends a pending invitation" do
        invitation = create(:tenant_invitation, tenant: tenant, invited_by: admin_user)

        expect {
          post resend_admin_invitation_path(invitation)
        }.to have_enqueued_mail(TenantInvitationMailer, :invite)

        expect(response).to redirect_to(admin_invitations_path)
      end

      it "rejects resending expired invitations" do
        invitation = create(:tenant_invitation, :expired, tenant: tenant, invited_by: admin_user)
        post resend_admin_invitation_path(invitation)
        expect(flash[:alert]).to include("Cannot resend")
      end
    end
  end
end
