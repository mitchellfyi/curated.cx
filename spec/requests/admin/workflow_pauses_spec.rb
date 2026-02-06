# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::WorkflowPauses", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let!(:site) { tenant.sites.first }
  let(:admin_user) { create(:user, :admin) }
  let(:tenant_admin) { create(:user).tap { |u| u.add_role(:admin, tenant) } }
  let(:regular_user) { create(:user) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /admin/workflow_pauses" do
    context "as admin" do
      before { sign_in admin_user }

      it "displays the index page" do
        get admin_workflow_pauses_path
        expect(response).to have_http_status(:success)
      end

      it "shows active pauses" do
        create(:workflow_pause, workflow_type: "rss_ingestion", tenant: nil, paused_by: admin_user)

        get admin_workflow_pauses_path

        expect(response).to have_http_status(:success)
      end

      it "shows pause history" do
        create(:workflow_pause, :resolved, workflow_type: "editorialisation", tenant: tenant, paused_by: admin_user)

        get admin_workflow_pauses_path

        expect(response).to have_http_status(:success)
      end
    end

    context "as tenant admin" do
      before { sign_in tenant_admin }

      it "displays the index page" do
        get admin_workflow_pauses_path
        expect(response).to have_http_status(:success)
      end
    end

    context "as regular user" do
      before { sign_in regular_user }

      it "denies access" do
        get admin_workflow_pauses_path

        expect(response).to redirect_to(root_path)
      end
    end

    context "as guest" do
      it "redirects to login" do
        get admin_workflow_pauses_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /admin/workflow_pauses/pause" do
    context "as admin" do
      before { sign_in admin_user }

      it "creates a pause" do
        expect {
          post pause_admin_workflow_pauses_path, params: {
            workflow_type: "rss_ingestion",
            reason: "Testing pause"
          }
        }.to change(WorkflowPause, :count).by(1)

        expect(response).to redirect_to(admin_workflow_pauses_path)
      end

      it "creates a global pause" do
        post pause_admin_workflow_pauses_path, params: {
          workflow_type: "rss_ingestion",
          global: "true"
        }

        pause = WorkflowPause.last
        expect(pause.tenant).to be_nil
      end

      context "with JSON format" do
        it "returns JSON response" do
          post pause_admin_workflow_pauses_path, params: { workflow_type: "editorialisation" }, as: :json

          expect(response).to have_http_status(:success)
          expect(response.content_type).to include("application/json")

          json = JSON.parse(response.body)
          expect(json["message"]).to eq("Paused successfully")
        end
      end
    end

    context "as tenant admin" do
      before { sign_in tenant_admin }

      it "can pause a workflow" do
        post pause_admin_workflow_pauses_path, params: {
          workflow_type: "editorialisation"
        }

        expect(response).to redirect_to(admin_workflow_pauses_path)
        expect(WorkflowPause.last.tenant).to eq(tenant)
      end
    end
  end

  describe "POST /admin/workflow_pauses/:id/resume" do
    let!(:pause) { create(:workflow_pause, workflow_type: "rss_ingestion", tenant: nil, paused_by: admin_user) }

    context "as admin" do
      before { sign_in admin_user }

      it "resumes the pause" do
        post resume_admin_workflow_pause_path(pause)

        expect(response).to redirect_to(admin_workflow_pauses_path)

        pause.reload
        expect(pause.resumed_at).to be_present
        expect(pause.resumed_by).to eq(admin_user)
      end

      context "with JSON format" do
        it "returns JSON response" do
          post resume_admin_workflow_pause_path(pause), as: :json

          expect(response).to have_http_status(:success)

          json = JSON.parse(response.body)
          expect(json["message"]).to eq("Resumed successfully")
        end
      end
    end
  end

  describe "GET /admin/workflow_pauses/backlog" do
    before { sign_in admin_user }

    it "returns backlog size as JSON" do
      get backlog_admin_workflow_pauses_path, params: { workflow_type: "editorialisation" }

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")

      json = JSON.parse(response.body)
      expect(json["workflow_type"]).to eq("editorialisation")
      expect(json["backlog_size"]).to be_a(Integer)
    end
  end
end
