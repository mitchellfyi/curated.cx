# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::ReferralRewardTiers", type: :request do
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
    describe "GET /admin/referral_reward_tiers" do
      context "when not signed in" do
        it "redirects to sign in" do
          get admin_referral_reward_tiers_path

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when signed in as regular user" do
        before { sign_in regular_user }

        it "denies access" do
          get admin_referral_reward_tiers_path

          expect(response).to redirect_to(root_path)
        end
      end

      context "when signed in as admin" do
        before { sign_in admin_user }

        it "allows access" do
          get admin_referral_reward_tiers_path

          expect(response).to have_http_status(:success)
        end
      end

      context "when signed in as tenant owner" do
        before { sign_in tenant_owner }

        it "allows access" do
          get admin_referral_reward_tiers_path

          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/referral_reward_tiers" do
    before { sign_in admin_user }

    context "with no tiers" do
      it "shows empty list" do
        get admin_referral_reward_tiers_path

        expect(assigns(:tiers)).to be_empty
      end
    end

    context "with tiers" do
      let!(:tier1) { create(:referral_reward_tier, site: site, milestone: 1) }
      let!(:tier3) { create(:referral_reward_tier, site: site, milestone: 3) }

      it "shows tiers ordered by milestone" do
        get admin_referral_reward_tiers_path

        tiers = assigns(:tiers)
        expect(tiers.first).to eq(tier1)
        expect(tiers.last).to eq(tier3)
      end
    end

    context "tenant isolation" do
      let!(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let!(:other_tier) { create(:referral_reward_tier, site: other_site) }
      let!(:site_tier) { create(:referral_reward_tier, site: site) }

      it "only shows tiers for current site" do
        get admin_referral_reward_tiers_path

        expect(assigns(:tiers)).to include(site_tier)
        expect(assigns(:tiers)).not_to include(other_tier)
      end
    end
  end

  describe "GET /admin/referral_reward_tiers/new" do
    before { sign_in admin_user }

    it "renders new form" do
      get new_admin_referral_reward_tier_path

      expect(response).to have_http_status(:success)
      expect(assigns(:tier)).to be_a_new(ReferralRewardTier)
    end
  end

  describe "POST /admin/referral_reward_tiers" do
    before { sign_in admin_user }

    let(:valid_params) do
      {
        referral_reward_tier: {
          milestone: 5,
          name: "Five Referrals Reward",
          reward_type: "digital_download",
          description: "A special bonus for reaching 5 referrals",
          active: true,
          reward_data: '{"download_url": "https://example.com/bonus.pdf"}'
        }
      }
    end

    context "with valid params" do
      it "creates a new tier" do
        expect {
          post admin_referral_reward_tiers_path, params: valid_params
        }.to change(ReferralRewardTier, :count).by(1)
      end

      it "sets the correct site" do
        post admin_referral_reward_tiers_path, params: valid_params

        tier = ReferralRewardTier.last
        expect(tier.site).to eq(site)
      end

      it "parses JSON reward_data" do
        post admin_referral_reward_tiers_path, params: valid_params

        tier = ReferralRewardTier.last
        expect(tier.reward_data["download_url"]).to eq("https://example.com/bonus.pdf")
      end

      it "redirects to index" do
        post admin_referral_reward_tiers_path, params: valid_params

        expect(response).to redirect_to(admin_referral_reward_tiers_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          referral_reward_tier: {
            milestone: nil,
            name: ""
          }
        }
      end

      it "does not create a tier" do
        expect {
          post admin_referral_reward_tiers_path, params: invalid_params
        }.not_to change(ReferralRewardTier, :count)
      end

      it "renders new with errors" do
        post admin_referral_reward_tiers_path, params: invalid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /admin/referral_reward_tiers/:id" do
    let!(:tier) { create(:referral_reward_tier, site: site) }

    before { sign_in admin_user }

    it "shows the tier" do
      get admin_referral_reward_tier_path(tier)

      expect(response).to have_http_status(:success)
      expect(assigns(:tier)).to eq(tier)
    end
  end

  describe "GET /admin/referral_reward_tiers/:id/edit" do
    let!(:tier) { create(:referral_reward_tier, site: site) }

    before { sign_in admin_user }

    it "renders edit form" do
      get edit_admin_referral_reward_tier_path(tier)

      expect(response).to have_http_status(:success)
      expect(assigns(:tier)).to eq(tier)
    end
  end

  describe "PATCH /admin/referral_reward_tiers/:id" do
    let!(:tier) { create(:referral_reward_tier, site: site, name: "Original Name") }

    before { sign_in admin_user }

    context "with valid params" do
      it "updates the tier" do
        patch admin_referral_reward_tier_path(tier), params: {
          referral_reward_tier: { name: "Updated Name" }
        }

        tier.reload
        expect(tier.name).to eq("Updated Name")
      end

      it "redirects to index" do
        patch admin_referral_reward_tier_path(tier), params: {
          referral_reward_tier: { name: "Updated Name" }
        }

        expect(response).to redirect_to(admin_referral_reward_tiers_path)
        expect(flash[:notice]).to be_present
      end
    end

    context "with invalid params" do
      it "renders edit with errors" do
        patch admin_referral_reward_tier_path(tier), params: {
          referral_reward_tier: { name: "" }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /admin/referral_reward_tiers/:id" do
    let!(:tier) { create(:referral_reward_tier, site: site) }

    before { sign_in admin_user }

    it "destroys the tier" do
      expect {
        delete admin_referral_reward_tier_path(tier)
      }.to change(ReferralRewardTier, :count).by(-1)
    end

    it "redirects to index" do
      delete admin_referral_reward_tier_path(tier)

      expect(response).to redirect_to(admin_referral_reward_tiers_path)
      expect(flash[:notice]).to be_present
    end
  end
end
