# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::EmailSteps", type: :request do
  let!(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:email_sequence) { create(:email_sequence, site: site) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "authentication and authorization" do
    describe "GET /admin/email_sequences/:email_sequence_id/email_steps/new" do
      context "when not signed in" do
        it "redirects to sign in" do
          get new_admin_email_sequence_email_step_path(email_sequence)

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when signed in as regular user" do
        before { sign_in regular_user }

        it "denies access" do
          get new_admin_email_sequence_email_step_path(email_sequence)

          expect(response).to redirect_to(root_path)
        end
      end

      context "when signed in as admin" do
        before { sign_in admin_user }

        it "allows access" do
          get new_admin_email_sequence_email_step_path(email_sequence)

          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/email_sequences/:email_sequence_id/email_steps/:id" do
    let!(:step) { create(:email_step, email_sequence: email_sequence, position: 0) }

    before { sign_in admin_user }

    it "shows the step" do
      get admin_email_sequence_email_step_path(email_sequence, step)

      expect(response).to have_http_status(:success)
      expect(assigns(:step)).to eq(step)
    end
  end

  describe "GET /admin/email_sequences/:email_sequence_id/email_steps/new" do
    before { sign_in admin_user }

    it "renders new form" do
      get new_admin_email_sequence_email_step_path(email_sequence)

      expect(response).to have_http_status(:success)
      expect(assigns(:step)).to be_a_new(EmailStep)
    end

    it "sets the next position" do
      create(:email_step, email_sequence: email_sequence, position: 0)
      create(:email_step, email_sequence: email_sequence, position: 1)

      get new_admin_email_sequence_email_step_path(email_sequence)

      expect(assigns(:step).position).to eq(2)
    end

    context "when no steps exist" do
      it "sets position to 0" do
        get new_admin_email_sequence_email_step_path(email_sequence)

        expect(assigns(:step).position).to eq(0)
      end
    end
  end

  describe "POST /admin/email_sequences/:email_sequence_id/email_steps" do
    before { sign_in admin_user }

    let(:valid_params) do
      {
        email_step: {
          position: 0,
          delay_seconds: 86_400,
          subject: "Welcome!",
          body_html: "<p>Welcome to our newsletter!</p>",
          body_text: "Welcome to our newsletter!"
        }
      }
    end

    context "with valid params" do
      it "creates a new step" do
        expect {
          post admin_email_sequence_email_steps_path(email_sequence), params: valid_params
        }.to change(EmailStep, :count).by(1)
      end

      it "associates step with sequence" do
        post admin_email_sequence_email_steps_path(email_sequence), params: valid_params

        step = EmailStep.last
        expect(step.email_sequence).to eq(email_sequence)
      end

      it "redirects to sequence show page" do
        post admin_email_sequence_email_steps_path(email_sequence), params: valid_params

        expect(response).to redirect_to(admin_email_sequence_path(email_sequence))
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          email_step: {
            subject: "",
            body_html: "",
            position: -1
          }
        }
      end

      it "does not create a step" do
        expect {
          post admin_email_sequence_email_steps_path(email_sequence), params: invalid_params
        }.not_to change(EmailStep, :count)
      end

      it "renders new with errors" do
        post admin_email_sequence_email_steps_path(email_sequence), params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/email_sequences/:email_sequence_id/email_steps/:id/edit" do
    let!(:step) { create(:email_step, email_sequence: email_sequence, position: 0) }

    before { sign_in admin_user }

    it "renders edit form" do
      get edit_admin_email_sequence_email_step_path(email_sequence, step)

      expect(response).to have_http_status(:success)
      expect(assigns(:step)).to eq(step)
    end
  end

  describe "PATCH /admin/email_sequences/:email_sequence_id/email_steps/:id" do
    let!(:step) { create(:email_step, email_sequence: email_sequence, position: 0, subject: "Original Subject") }

    before { sign_in admin_user }

    context "with valid params" do
      it "updates the step" do
        patch admin_email_sequence_email_step_path(email_sequence, step), params: {
          email_step: { subject: "Updated Subject" }
        }

        step.reload
        expect(step.subject).to eq("Updated Subject")
      end

      it "redirects to sequence show page" do
        patch admin_email_sequence_email_step_path(email_sequence, step), params: {
          email_step: { subject: "Updated Subject" }
        }

        expect(response).to redirect_to(admin_email_sequence_path(email_sequence))
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid params" do
      it "renders edit with errors" do
        patch admin_email_sequence_email_step_path(email_sequence, step), params: {
          email_step: { subject: "" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/email_sequences/:email_sequence_id/email_steps/:id" do
    let!(:step) { create(:email_step, email_sequence: email_sequence, position: 0) }

    before { sign_in admin_user }

    it "destroys the step" do
      expect {
        delete admin_email_sequence_email_step_path(email_sequence, step)
      }.to change(EmailStep, :count).by(-1)
    end

    it "redirects to sequence show page" do
      delete admin_email_sequence_email_step_path(email_sequence, step)

      expect(response).to redirect_to(admin_email_sequence_path(email_sequence))
      expect(flash[:notice]).to be_present
    end
  end
end
