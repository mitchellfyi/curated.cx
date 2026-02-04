# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::WorkflowPauses" do
  let(:admin_user) { create(:user, :admin) }
  let(:tenant) { create(:tenant) }
  let(:tenant_admin) { create(:user).tap { |u| u.add_role(:admin, tenant) } }
  let(:regular_user) { create(:user) }

  before do
    # Set up tenant context
    allow_any_instance_of(ApplicationController).to receive(:current_tenant).and_return(tenant)
    Current.tenant = tenant
  end

  after do
    Current.tenant = nil
  end

  describe "GET /admin/workflow_pauses" do
    context "as admin" do
      before { sign_in admin_user }

      it "displays the index page" do
        get admin_workflow_pauses_path
        expect(response).to have_http_status(:success)
      end

      it "shows active pauses" do
        pause = create(:workflow_pause, workflow_type: "rss_ingestion", tenant: nil)

        get admin_workflow_pauses_path

        expect(response.body).to include("Rss Ingestion")
        expect(response.body).to include("Active Pauses")
      end

      it "shows pause history" do
        resolved = create(:workflow_pause, :resolved, workflow_type: "editorialisation", tenant: tenant)

        get admin_workflow_pauses_path

        expect(response.body).to include("Recent History")
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
        expect(response).to redirect_to(new_user_session_path).or have_http_status(:forbidden)
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

      it "creates a global pause" do
        expect {
          post pause_admin_workflow_pauses_path, params: {
            workflow_type: "rss_ingestion",
            reason: "Testing pause"
          }
        }.to change(WorkflowPause, :count).by(1)

        expect(response).to redirect_to(admin_workflow_pauses_path)
        follow_redirect!
        expect(response.body).to include("paused successfully")
      end

      it "creates a tenant-specific pause" do
        expect {
          post pause_admin_workflow_pauses_path, params: {
            workflow_type: "editorialisation",
            tenant_id: tenant.id
          }
        }.to change(WorkflowPause, :count).by(1)

        pause = WorkflowPause.last
        expect(pause.tenant).to eq(tenant)
      end

      it "handles duplicate pause gracefully" do
        create(:workflow_pause, workflow_type: "rss_ingestion", tenant: nil, paused_by: admin_user)

        expect {
          post pause_admin_workflow_pauses_path, params: { workflow_type: "rss_ingestion" }
        }.not_to change(WorkflowPause, :count)

        expect(response).to redirect_to(admin_workflow_pauses_path)
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

      it "can pause their tenant's workflow" do
        post pause_admin_workflow_pauses_path, params: {
          workflow_type: "editorialisation",
          tenant_id: tenant.id
        }

        expect(response).to redirect_to(admin_workflow_pauses_path)
        expect(WorkflowPause.last.tenant).to eq(tenant)
      end

      it "cannot create global pause" do
        post pause_admin_workflow_pauses_path, params: { workflow_type: "editorialisation" }

        expect(response).to redirect_to(admin_workflow_pauses_path)
        follow_redirect!
        expect(response.body).to include("super admin")
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
        follow_redirect!
        expect(response.body).to include("resumed successfully")

        pause.reload
        expect(pause.resumed_at).to be_present
        expect(pause.resumed_by).to eq(admin_user)
      end

      it "processes backlog when requested" do
        # We'd need to mock the actual job processing
        expect(WorkflowPauseService).to receive(:resume!).with(
          "rss_ingestion",
          by: admin_user,
          tenant: nil,
          source: nil,
          process_backlog: true
        ).and_call_original

        post resume_admin_workflow_pause_path(pause, process_backlog: "true")

        expect(response).to redirect_to(admin_workflow_pauses_path)
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
