# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::EmailSequences", type: :request do
  let!(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:tenant_owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "authentication and authorization" do
    describe "GET /admin/email_sequences" do
      context "when not signed in" do
        it "redirects to sign in" do
          get admin_email_sequences_path

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when signed in as regular user" do
        before { sign_in regular_user }

        it "denies access" do
          get admin_email_sequences_path

          expect(response).to redirect_to(root_path)
        end
      end

      context "when signed in as admin" do
        before { sign_in admin_user }

        it "allows access" do
          get admin_email_sequences_path

          expect(response).to have_http_status(:success)
        end
      end

      context "when signed in as tenant owner" do
        before { sign_in tenant_owner }

        it "allows access" do
          get admin_email_sequences_path

          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/email_sequences" do
    before { sign_in admin_user }

    context "with no sequences" do
      it "shows empty list" do
        get admin_email_sequences_path

        expect(assigns(:sequences)).to be_empty
      end
    end

    context "with sequences" do
      let!(:sequence1) { create(:email_sequence, site: site, name: "Welcome") }
      let!(:sequence2) { create(:email_sequence, site: site, name: "Onboarding") }

      it "shows sequences ordered by created_at descending" do
        get admin_email_sequences_path

        sequences = assigns(:sequences)
        expect(sequences.first).to eq(sequence2)
        expect(sequences.last).to eq(sequence1)
      end
    end

    context "tenant isolation" do
      let!(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let!(:other_sequence) { create(:email_sequence, site: other_site) }
      let!(:site_sequence) { create(:email_sequence, site: site) }

      it "only shows sequences for current site" do
        get admin_email_sequences_path

        expect(assigns(:sequences)).to include(site_sequence)
        expect(assigns(:sequences)).not_to include(other_sequence)
      end
    end
  end

  describe "GET /admin/email_sequences/new" do
    before { sign_in admin_user }

    it "renders new form" do
      get new_admin_email_sequence_path

      expect(response).to have_http_status(:success)
      expect(assigns(:sequence)).to be_a_new(EmailSequence)
    end
  end

  describe "POST /admin/email_sequences" do
    before { sign_in admin_user }

    let(:valid_params) do
      {
        email_sequence: {
          name: "Welcome Sequence",
          trigger_type: "subscriber_joined",
          enabled: true,
          trigger_config: '{"key": "value"}'
        }
      }
    end

    context "with valid params" do
      it "creates a new sequence" do
        expect {
          post admin_email_sequences_path, params: valid_params
        }.to change(EmailSequence, :count).by(1)
      end

      it "sets the correct site" do
        post admin_email_sequences_path, params: valid_params

        sequence = EmailSequence.last
        expect(sequence.site).to eq(site)
      end

      it "parses JSON trigger_config" do
        post admin_email_sequences_path, params: valid_params

        sequence = EmailSequence.last
        expect(sequence.trigger_config["key"]).to eq("value")
      end

      it "redirects to show page" do
        post admin_email_sequences_path, params: valid_params

        expect(response).to redirect_to(admin_email_sequence_path(EmailSequence.last))
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          email_sequence: {
            name: "",
            trigger_type: nil
          }
        }
      end

      it "does not create a sequence" do
        expect {
          post admin_email_sequences_path, params: invalid_params
        }.not_to change(EmailSequence, :count)
      end

      it "renders new with errors" do
        post admin_email_sequences_path, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/email_sequences/:id" do
    let!(:sequence) { create(:email_sequence, :with_steps, site: site) }

    before { sign_in admin_user }

    it "shows the sequence" do
      get admin_email_sequence_path(sequence)

      expect(response).to have_http_status(:success)
      expect(assigns(:sequence)).to eq(sequence)
    end

    it "includes ordered steps" do
      get admin_email_sequence_path(sequence)

      expect(assigns(:steps)).to eq(sequence.email_steps.ordered)
    end
  end

  describe "GET /admin/email_sequences/:id/edit" do
    let!(:sequence) { create(:email_sequence, site: site) }

    before { sign_in admin_user }

    it "renders edit form" do
      get edit_admin_email_sequence_path(sequence)

      expect(response).to have_http_status(:success)
      expect(assigns(:sequence)).to eq(sequence)
    end
  end

  describe "PATCH /admin/email_sequences/:id" do
    let!(:sequence) { create(:email_sequence, site: site, name: "Original Name") }

    before { sign_in admin_user }

    context "with valid params" do
      it "updates the sequence" do
        patch admin_email_sequence_path(sequence), params: {
          email_sequence: { name: "Updated Name" }
        }

        sequence.reload
        expect(sequence.name).to eq("Updated Name")
      end

      it "redirects to show page" do
        patch admin_email_sequence_path(sequence), params: {
          email_sequence: { name: "Updated Name" }
        }

        expect(response).to redirect_to(admin_email_sequence_path(sequence))
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid params" do
      it "renders edit with errors" do
        patch admin_email_sequence_path(sequence), params: {
          email_sequence: { name: "" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/email_sequences/:id" do
    let!(:sequence) { create(:email_sequence, site: site) }

    before { sign_in admin_user }

    it "destroys the sequence" do
      expect {
        delete admin_email_sequence_path(sequence)
      }.to change(EmailSequence, :count).by(-1)
    end

    it "redirects to index" do
      delete admin_email_sequence_path(sequence)

      expect(response).to redirect_to(admin_email_sequences_path)
      expect(flash[:notice]).to be_present
    end
  end

  describe "POST /admin/email_sequences/:id/enable" do
    let!(:sequence) { create(:email_sequence, site: site, enabled: false) }

    before { sign_in admin_user }

    it "enables the sequence" do
      post enable_admin_email_sequence_path(sequence)

      sequence.reload
      expect(sequence.enabled).to be true
    end

    it "redirects to show page" do
      post enable_admin_email_sequence_path(sequence)

      expect(response).to redirect_to(admin_email_sequence_path(sequence))
      expect(flash[:notice]).to be_present
    end
  end

  describe "POST /admin/email_sequences/:id/disable" do
    let!(:sequence) { create(:email_sequence, :enabled, site: site) }

    before { sign_in admin_user }

    it "disables the sequence" do
      post disable_admin_email_sequence_path(sequence)

      sequence.reload
      expect(sequence.enabled).to be false
    end

    it "redirects to show page" do
      post disable_admin_email_sequence_path(sequence)

      expect(response).to redirect_to(admin_email_sequence_path(sequence))
      expect(flash[:notice]).to be_present
    end
  end
end
