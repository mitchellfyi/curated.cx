# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Referrals", type: :request do
  let!(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:tenant_owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }

  let(:referrer_user) { create(:user) }
  let(:referee_user) { create(:user) }
  let(:referrer_subscription) { create(:digest_subscription, user: referrer_user, site: site) }
  let(:referee_subscription) { create(:digest_subscription, user: referee_user, site: site) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "authentication and authorization" do
    describe "GET /admin/referrals" do
      context "when not signed in" do
        it "redirects to sign in" do
          get admin_referrals_path

          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "when signed in as regular user" do
        before { sign_in regular_user }

        it "denies access" do
          get admin_referrals_path

          expect(response).to redirect_to(root_path)
        end
      end

      context "when signed in as admin" do
        before { sign_in admin_user }

        it "allows access" do
          get admin_referrals_path

          expect(response).to have_http_status(:success)
        end
      end

      context "when signed in as tenant owner" do
        before { sign_in tenant_owner }

        it "allows access" do
          get admin_referrals_path

          expect(response).to have_http_status(:success)
        end
      end
    end
  end

  describe "GET /admin/referrals" do
    before { sign_in admin_user }

    context "with no referrals" do
      it "shows empty stats" do
        get admin_referrals_path

        expect(assigns(:stats)[:total]).to eq(0)
        expect(assigns(:stats)[:pending]).to eq(0)
        expect(assigns(:stats)[:confirmed]).to eq(0)
      end
    end

    context "with referrals" do
      let!(:pending_referral) { create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site, status: :pending) }

      it "shows referrals" do
        get admin_referrals_path

        expect(assigns(:referrals)).to include(pending_referral)
      end

      it "shows stats" do
        get admin_referrals_path

        expect(assigns(:stats)[:total]).to eq(1)
        expect(assigns(:stats)[:pending]).to eq(1)
      end

      it "calculates conversion rate" do
        # Add a confirmed referral
        another_referee = create(:user)
        another_referee_sub = create(:digest_subscription, user: another_referee, site: site)
        create(:referral, :confirmed, referrer_subscription: referrer_subscription, referee_subscription: another_referee_sub, site: site)

        get admin_referrals_path

        # 1 confirmed out of 2 total = 50%
        expect(assigns(:stats)[:conversion_rate]).to eq(50.0)
      end
    end

    context "tenant isolation" do
      let!(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { create(:site, tenant: other_tenant) }
      let(:other_referrer) { create(:user) }
      let(:other_referee) { create(:user) }
      let(:other_referrer_sub) { create(:digest_subscription, user: other_referrer, site: other_site) }
      let(:other_referee_sub) { create(:digest_subscription, user: other_referee, site: other_site) }
      let!(:other_referral) { create(:referral, referrer_subscription: other_referrer_sub, referee_subscription: other_referee_sub, site: other_site) }

      let!(:site_referral) { create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site) }

      it "only shows referrals for current site" do
        get admin_referrals_path

        expect(assigns(:referrals)).to include(site_referral)
        expect(assigns(:referrals)).not_to include(other_referral)
      end
    end
  end

  describe "GET /admin/referrals/:id" do
    let!(:referral) { create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site) }

    before { sign_in admin_user }

    it "shows the referral" do
      get admin_referral_path(referral)

      expect(response).to have_http_status(:success)
      expect(assigns(:referral)).to eq(referral)
    end
  end

  describe "PATCH /admin/referrals/:id" do
    before { sign_in admin_user }

    context "when referral is confirmed" do
      let!(:referral) { create(:referral, :confirmed, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site) }

      it "marks as rewarded" do
        patch admin_referral_path(referral), params: { mark_rewarded: true }

        referral.reload
        expect(referral.status).to eq("rewarded")
        expect(referral.rewarded_at).to be_present
      end

      it "redirects with success notice" do
        patch admin_referral_path(referral), params: { mark_rewarded: true }

        expect(response).to redirect_to(admin_referral_path(referral))
        expect(flash[:notice]).to be_present
      end
    end

    context "when referral is not confirmed" do
      let!(:referral) { create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site, status: :pending) }

      it "does not mark as rewarded" do
        patch admin_referral_path(referral), params: { mark_rewarded: true }

        referral.reload
        expect(referral.status).to eq("pending")
      end

      it "redirects with alert" do
        patch admin_referral_path(referral), params: { mark_rewarded: true }

        expect(response).to redirect_to(admin_referral_path(referral))
        expect(flash[:alert]).to be_present
      end
    end

    context "without mark_rewarded param" do
      let!(:referral) { create(:referral, :confirmed, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site) }

      it "does not change status" do
        patch admin_referral_path(referral)

        referral.reload
        expect(referral.status).to eq("confirmed")
      end
    end
  end
end
