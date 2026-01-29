# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Submissions", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:category) { create(:category, site: site, tenant: tenant) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /submissions" do
    context "when not signed in" do
      it "redirects to sign in" do
        get submissions_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns http success" do
        get submissions_path

        expect(response).to have_http_status(:success)
      end

      it "shows user's submissions" do
        submission = create(:submission, user: user, site: site, category: category)

        get submissions_path

        expect(response.body).to include(submission.title)
      end

      it "does not show other users' submissions" do
        other_user = create(:user)
        other_submission = create(:submission, user: other_user, site: site, category: category)

        get submissions_path

        expect(response.body).not_to include(other_submission.title)
      end
    end
  end

  describe "GET /submissions/new" do
    context "when not signed in" do
      it "redirects to sign in" do
        get new_submission_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns http success" do
        get new_submission_path

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "POST /submissions" do
    context "when not signed in" do
      it "redirects to sign in" do
        post submissions_path, params: { submission: { url: "https://example.com", title: "Test" } }

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "creates a submission with valid params" do
        expect {
          post submissions_path, params: {
            submission: {
              url: "https://example.com",
              title: "Test Submission",
              description: "A test description",
              category_id: category.id,
              listing_type: :tool
            }
          }
        }.to change(Submission, :count).by(1)
      end

      it "redirects on success" do
        post submissions_path, params: {
          submission: {
            url: "https://example.com",
            title: "Test Submission",
            category_id: category.id,
            listing_type: :tool
          }
        }

        expect(response).to redirect_to(submissions_path)
      end

      it "sets the current user as submitter" do
        post submissions_path, params: {
          submission: {
            url: "https://example.com",
            title: "Test Submission",
            category_id: category.id,
            listing_type: :tool
          }
        }

        expect(Submission.last.user).to eq(user)
      end

      it "records IP address" do
        post submissions_path, params: {
          submission: {
            url: "https://example.com",
            title: "Test Submission",
            category_id: category.id,
            listing_type: :tool
          }
        }

        expect(Submission.last.ip_address).to be_present
      end

      it "returns error with invalid params" do
        post submissions_path, params: {
          submission: {
            url: "",
            title: "",
            category_id: category.id
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /submissions/:id" do
    let(:submission) { create(:submission, user: user, site: site, category: category) }

    context "when not signed in" do
      it "redirects to sign in" do
        get submission_path(submission)

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in as submission owner" do
      before { sign_in user }

      it "returns http success" do
        get submission_path(submission)

        expect(response).to have_http_status(:success)
      end
    end

    context "when signed in as different user" do
      let(:other_user) { create(:user) }

      before { sign_in other_user }

      it "denies access" do
        get submission_path(submission)

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
