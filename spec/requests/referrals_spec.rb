# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Referrals", type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:subscription) { create(:digest_subscription, user: user, site: site) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /referrals" do
    context "when not signed in" do
      it "redirects to sign in" do
        get referrals_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in without subscription" do
      before { sign_in user }

      it "redirects to subscribe first" do
        get referrals_path

        expect(response).to redirect_to(digest_subscription_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when signed in with subscription" do
      before do
        sign_in user
        subscription
      end

      it "returns http success" do
        get referrals_path

        expect(response).to have_http_status(:success)
      end

      it "assigns the subscription" do
        get referrals_path

        expect(assigns(:subscription)).to eq(subscription)
      end

      it "displays referral code" do
        get referrals_path

        expect(response.body).to include(subscription.referral_code)
      end

      it "displays progress information" do
        get referrals_path

        expect(assigns(:progress)).to be_present
        expect(assigns(:progress)[:confirmed_count]).to eq(0)
      end

      context "with referrals" do
        let!(:referee) { create(:user) }
        let!(:referee_subscription) { create(:digest_subscription, user: referee, site: site) }
        let!(:referral) { create(:referral, :confirmed, referrer_subscription: subscription, referee_subscription: referee_subscription, site: site) }

        it "displays referral count" do
          get referrals_path

          expect(assigns(:progress)[:confirmed_count]).to eq(1)
        end

        it "includes referrals in the list" do
          get referrals_path

          expect(assigns(:referrals)).to include(referral)
        end
      end

      context "with reward tiers" do
        let!(:tier) { create(:referral_reward_tier, :first_referral, site: site) }

        it "displays next reward information" do
          get referrals_path

          expect(assigns(:progress)[:next_milestone]).to eq(1)
        end

        context "when tier is earned" do
          before do
            referee = create(:user)
            referee_sub = create(:digest_subscription, user: referee, site: site)
            create(:referral, :confirmed, referrer_subscription: subscription, referee_subscription: referee_sub, site: site)
          end

          it "includes tier in earned_rewards" do
            get referrals_path

            expect(assigns(:earned_rewards)).to include(tier)
          end
        end
      end
    end
  end
end
