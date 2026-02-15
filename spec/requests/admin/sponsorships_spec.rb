# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Sponsorships", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:category) { create(:category, site: site, tenant: tenant) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
    sign_in admin_user
  end

  describe "GET /admin/sponsorships" do
    context "when there are no sponsorships" do
      it "returns http success" do
        get admin_sponsorships_path

        expect(response).to have_http_status(:success)
      end
    end

    context "when there are sponsorships" do
      let!(:sponsorships) do
        [
          create(:sponsorship, :active, site: site),
          create(:sponsorship, :pending, site: site),
          create(:sponsorship, :paused, site: site)
        ]
      end

      it "returns http success" do
        get admin_sponsorships_path

        expect(response).to have_http_status(:success)
      end

      it "displays all sponsorships" do
        get admin_sponsorships_path

        expect(response.body).to include("active")
        expect(response.body).to include("pending")
        expect(response.body).to include("paused")
      end
    end

    context "with status filter" do
      let!(:active_sponsorship) { create(:sponsorship, :active, site: site) }
      let!(:pending_sponsorship) { create(:sponsorship, :pending, site: site) }

      it "filters by active status" do
        get admin_sponsorships_path(status: "active")

        expect(assigns(:sponsorships)).to include(active_sponsorship)
        expect(assigns(:sponsorships)).not_to include(pending_sponsorship)
      end

      it "filters by pending status" do
        get admin_sponsorships_path(status: "pending")

        expect(assigns(:sponsorships)).to include(pending_sponsorship)
        expect(assigns(:sponsorships)).not_to include(active_sponsorship)
      end
    end

    context "with placement_type filter" do
      let!(:featured_sponsorship) { create(:sponsorship, :featured, site: site) }
      let!(:boosted_sponsorship) { create(:sponsorship, :boosted, site: site) }

      it "filters by placement type" do
        get admin_sponsorships_path(placement_type: "featured")

        expect(assigns(:sponsorships)).to include(featured_sponsorship)
        expect(assigns(:sponsorships)).not_to include(boosted_sponsorship)
      end
    end
  end

  describe "GET /admin/sponsorships/:id" do
    let!(:sponsorship) { create(:sponsorship, :with_entry, :with_performance, site: site) }

    it "returns http success" do
      get admin_sponsorship_path(sponsorship)

      expect(response).to have_http_status(:success)
    end

    it "displays sponsorship details" do
      get admin_sponsorship_path(sponsorship)

      expect(response.body).to include(sponsorship.entry.title)
      expect(response.body).to include(sponsorship.user.email)
    end

    it "prevents N+1 queries by eager loading" do
      expect do
        get admin_sponsorship_path(sponsorship)
      end.not_to exceed_query_limit(10)
    end
  end

  describe "GET /admin/sponsorships/new" do
    it "returns http success" do
      get new_admin_sponsorship_path

      expect(response).to have_http_status(:success)
    end

    it "initializes a new sponsorship" do
      get new_admin_sponsorship_path

      expect(assigns(:sponsorship)).to be_a_new(Sponsorship)
      expect(assigns(:sponsorship).site).to eq(site)
    end
  end

  describe "POST /admin/sponsorships" do
    let(:user) { create(:user) }
    let(:entry) { create(:entry, :directory, site: site, category: category) }
    let(:valid_params) do
      {
        sponsorship: {
          user_id: user.id,
          entry_id: entry.id,
          placement_type: "featured",
          starts_at: Time.current,
          ends_at: 30.days.from_now,
          budget_cents: 10_000
        }
      }
    end

    it "creates a new sponsorship" do
      expect do
        post admin_sponsorships_path, params: valid_params
      end.to change(Sponsorship, :count).by(1)
    end

    it "assigns the current site" do
      post admin_sponsorships_path, params: valid_params

      expect(Sponsorship.last.site).to eq(site)
    end

    it "redirects to the sponsorship show page" do
      post admin_sponsorships_path, params: valid_params

      expect(response).to redirect_to(admin_sponsorship_path(Sponsorship.last))
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          sponsorship: {
            placement_type: "",
            starts_at: Time.current,
            ends_at: 30.days.from_now
          }
        }
      end

      it "does not create a sponsorship" do
        expect do
          post admin_sponsorships_path, params: invalid_params
        end.not_to change(Sponsorship, :count)
      end

      it "renders the new template" do
        post admin_sponsorships_path, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/sponsorships/:id/edit" do
    let!(:sponsorship) { create(:sponsorship, site: site) }

    it "returns http success" do
      get edit_admin_sponsorship_path(sponsorship)

      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /admin/sponsorships/:id" do
    let!(:sponsorship) { create(:sponsorship, site: site, budget_cents: 10_000) }
    let(:update_params) do
      {
        sponsorship: {
          budget_cents: 20_000
        }
      }
    end

    it "updates the sponsorship" do
      patch admin_sponsorship_path(sponsorship), params: update_params

      expect(sponsorship.reload.budget_cents).to eq(20_000)
    end

    it "redirects to the sponsorship show page" do
      patch admin_sponsorship_path(sponsorship), params: update_params

      expect(response).to redirect_to(admin_sponsorship_path(sponsorship))
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          sponsorship: {
            placement_type: "invalid"
          }
        }
      end

      it "does not update the sponsorship" do
        original_placement = sponsorship.placement_type
        patch admin_sponsorship_path(sponsorship), params: invalid_params

        expect(sponsorship.reload.placement_type).to eq(original_placement)
      end

      it "renders the edit template" do
        patch admin_sponsorship_path(sponsorship), params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/sponsorships/:id" do
    let!(:sponsorship) { create(:sponsorship, site: site) }

    it "destroys the sponsorship" do
      expect do
        delete admin_sponsorship_path(sponsorship)
      end.to change(Sponsorship, :count).by(-1)
    end

    it "redirects to the sponsorships index" do
      delete admin_sponsorship_path(sponsorship)

      expect(response).to redirect_to(admin_sponsorships_path)
    end
  end

  describe "POST /admin/sponsorships/:id/approve" do
    let!(:sponsorship) { create(:sponsorship, :pending, site: site) }

    it "approves the sponsorship" do
      post approve_admin_sponsorship_path(sponsorship)

      expect(sponsorship.reload.status).to eq("active")
    end

    it "redirects to the sponsorship show page" do
      post approve_admin_sponsorship_path(sponsorship)

      expect(response).to redirect_to(admin_sponsorship_path(sponsorship))
    end
  end

  describe "POST /admin/sponsorships/:id/pause" do
    let!(:sponsorship) { create(:sponsorship, :active, site: site) }

    it "pauses the sponsorship" do
      post pause_admin_sponsorship_path(sponsorship)

      expect(sponsorship.reload.status).to eq("paused")
    end

    it "redirects to the sponsorship show page" do
      post pause_admin_sponsorship_path(sponsorship)

      expect(response).to redirect_to(admin_sponsorship_path(sponsorship))
    end
  end

  describe "POST /admin/sponsorships/:id/complete" do
    let!(:sponsorship) { create(:sponsorship, :active, site: site) }

    it "completes the sponsorship" do
      post complete_admin_sponsorship_path(sponsorship)

      expect(sponsorship.reload.status).to eq("completed")
    end

    it "redirects to the sponsorship show page" do
      post complete_admin_sponsorship_path(sponsorship)

      expect(response).to redirect_to(admin_sponsorship_path(sponsorship))
    end
  end

  describe "POST /admin/sponsorships/:id/reject" do
    let!(:sponsorship) { create(:sponsorship, :pending, site: site) }

    it "rejects the sponsorship" do
      post reject_admin_sponsorship_path(sponsorship)

      expect(sponsorship.reload.status).to eq("rejected")
    end

    it "redirects to the sponsorship show page" do
      post reject_admin_sponsorship_path(sponsorship)

      expect(response).to redirect_to(admin_sponsorship_path(sponsorship))
    end
  end

  describe "authorization" do
    context "when not signed in" do
      before { sign_out admin_user }

      it "redirects to sign in" do
        get admin_sponsorships_path

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
        get admin_sponsorships_path

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
