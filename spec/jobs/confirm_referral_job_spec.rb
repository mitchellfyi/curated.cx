# frozen_string_literal: true

require "rails_helper"

RSpec.describe ConfirmReferralJob, type: :job do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:referrer_user) { create(:user) }
  let(:referee_user) { create(:user) }
  let(:referrer_subscription) { create(:digest_subscription, user: referrer_user, site: site) }
  let(:referee_subscription) { create(:digest_subscription, user: referee_user, site: site, active: true) }
  let(:referral) { create(:referral, referrer_subscription: referrer_subscription, referee_subscription: referee_subscription, site: site, status: :pending) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#perform" do
    context "when referral does not exist" do
      it "returns early without error" do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end

    context "when referral is not pending" do
      it "skips already confirmed referrals" do
        referral.update!(status: :confirmed, confirmed_at: Time.current)

        expect(referral).not_to receive(:confirm!)
        described_class.perform_now(referral.id)

        expect(referral.reload.status).to eq("confirmed")
      end

      it "skips cancelled referrals" do
        referral.update!(status: :cancelled)

        described_class.perform_now(referral.id)

        expect(referral.reload.status).to eq("cancelled")
      end

      it "skips rewarded referrals" do
        referral.update!(status: :rewarded, confirmed_at: 1.day.ago, rewarded_at: Time.current)

        described_class.perform_now(referral.id)

        expect(referral.reload.status).to eq("rewarded")
      end
    end

    context "when referee subscription is still active" do
      it "confirms the referral" do
        freeze_time do
          described_class.perform_now(referral.id)

          referral.reload
          expect(referral.status).to eq("confirmed")
          expect(referral.confirmed_at).to eq(Time.current)
        end
      end

      it "sends confirmation email" do
        expect {
          described_class.perform_now(referral.id)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "checks and awards milestone rewards" do
        tier = create(:referral_reward_tier, site: site, milestone: 1)

        expect {
          described_class.perform_now(referral.id)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob).at_least(:twice)
        # One for confirmation, one for reward
      end
    end

    context "when referee has unsubscribed" do
      before do
        referee_subscription.update!(active: false)
      end

      it "cancels the referral" do
        described_class.perform_now(referral.id)

        referral.reload
        expect(referral.status).to eq("cancelled")
      end

      it "does not send confirmation email" do
        expect {
          described_class.perform_now(referral.id)
        }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it "logs the cancellation" do
        allow(Rails.logger).to receive(:info)

        described_class.perform_now(referral.id)

        expect(Rails.logger).to have_received(:info).with(/cancelled: referee unsubscribed/)
      end
    end

    context "when an error occurs" do
      before do
        allow(Referral).to receive(:find_by).and_call_original
        allow_any_instance_of(Referral).to receive(:confirm!).and_raise(StandardError, "Test error")
      end

      it "re-raises the error" do
        expect {
          described_class.perform_now(referral.id)
        }.to raise_error(StandardError, "Test error")
      end
    end

    it "can be enqueued" do
      expect {
        described_class.perform_later(referral.id)
      }.to have_enqueued_job(described_class)
    end

    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
