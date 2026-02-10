# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Submissions", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:category) { create(:category, site: site, tenant: tenant) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    sign_in admin_user
  end

  describe "GET /admin/submissions" do
    it "returns http success" do
      get admin_submissions_path

      expect(response).to have_http_status(:success)
    end

    it "shows pending submissions by default" do
      pending_submission = create(:submission, :pending, site: site, category: category)
      approved_submission = create(:submission, :approved, site: site, category: category)

      get admin_submissions_path

      expect(response.body).to include(pending_submission.title)
    end

    it "filters by status" do
      pending_submission = create(:submission, :pending, site: site, category: category)
      approved_submission = create(:submission, :approved, site: site, category: category)

      get admin_submissions_path(status: "approved")

      expect(response.body).to include(approved_submission.title)
      expect(response.body).not_to include(pending_submission.title)
    end

    it "shows stats" do
      create_list(:submission, 2, :pending, site: site, category: category)
      create(:submission, :approved, site: site, category: category)

      get admin_submissions_path

      expect(assigns(:stats)[:pending]).to eq(2)
      expect(assigns(:stats)[:approved]).to eq(1)
    end
  end

  describe "POST /admin/submissions/:id/approve" do
    let(:submission) { create(:submission, :pending, site: site, category: category) }

    it "approves the submission" do
      post approve_admin_submission_path(submission)

      expect(submission.reload.status).to eq("approved")
    end

    it "creates an entry" do
      expect {
        post approve_admin_submission_path(submission)
      }.to change(Entry, :count).by(1)
    end

    it "sets reviewer" do
      post approve_admin_submission_path(submission)

      expect(submission.reload.reviewer).to eq(admin_user)
    end

    it "redirects to index" do
      post approve_admin_submission_path(submission)

      expect(response).to redirect_to(admin_submissions_path)
    end

    it "accepts reviewer notes" do
      post approve_admin_submission_path(submission), params: { notes: "Great content!" }

      expect(submission.reload.reviewer_notes).to eq("Great content!")
    end
  end

  describe "POST /admin/submissions/:id/reject" do
    let(:submission) { create(:submission, :pending, site: site, category: category) }

    it "rejects the submission" do
      post reject_admin_submission_path(submission)

      expect(submission.reload.status).to eq("rejected")
    end

    it "does not create an entry" do
      expect {
        post reject_admin_submission_path(submission)
      }.not_to change(Entry, :count)
    end

    it "sets reviewer" do
      post reject_admin_submission_path(submission)

      expect(submission.reload.reviewer).to eq(admin_user)
    end

    it "accepts rejection reason" do
      post reject_admin_submission_path(submission), params: { notes: "Does not meet guidelines" }

      expect(submission.reload.reviewer_notes).to eq("Does not meet guidelines")
    end
  end

  describe "authorization" do
    context "when not signed in" do
      before { sign_out admin_user }

      it "redirects to sign in" do
        get admin_submissions_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as regular user" do
      let(:regular_user) { create(:user) }

      before do
        sign_out admin_user
        sign_in regular_user
      end

      it "denies access" do
        get admin_submissions_path

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
