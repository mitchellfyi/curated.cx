# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendDigestEmailsJob, type: :job do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "#perform" do
    context "with unknown frequency" do
      it "logs a warning" do
        allow(Rails.logger).to receive(:warn)

        described_class.perform_now(frequency: "invalid")

        expect(Rails.logger).to have_received(:warn).with(/Unknown digest frequency: invalid/)
      end
    end

    context "weekly digests" do
      let!(:weekly_user) { create(:user) }
      let!(:weekly_sub) { create(:digest_subscription, :due, user: weekly_user, site: site, frequency: :weekly) }
      let!(:daily_user) { create(:user) }
      let!(:daily_sub) { create(:digest_subscription, :due, user: daily_user, site: site, frequency: :daily) }

      it "sends to weekly subscribers" do
        allow(DigestMailer).to receive(:weekly_digest).and_call_original

        described_class.perform_now(frequency: "weekly")

        expect(DigestMailer).to have_received(:weekly_digest).with(weekly_sub)
      end

      it "does not send to daily subscribers" do
        allow(DigestMailer).to receive(:weekly_digest).and_call_original

        described_class.perform_now(frequency: "weekly")

        expect(DigestMailer).not_to have_received(:weekly_digest).with(daily_sub)
      end
    end

    context "daily digests" do
      let!(:weekly_user) { create(:user) }
      let!(:weekly_sub) { create(:digest_subscription, :due, user: weekly_user, site: site, frequency: :weekly) }
      let!(:daily_user) { create(:user) }
      let!(:daily_sub) { create(:digest_subscription, :due, user: daily_user, site: site, frequency: :daily) }

      it "sends to daily subscribers" do
        allow(DigestMailer).to receive(:daily_digest).and_call_original

        described_class.perform_now(frequency: "daily")

        expect(DigestMailer).to have_received(:daily_digest).with(daily_sub)
      end

      it "does not send to weekly subscribers" do
        allow(DigestMailer).to receive(:daily_digest).and_call_original

        described_class.perform_now(frequency: "daily")

        expect(DigestMailer).not_to have_received(:daily_digest).with(weekly_sub)
      end
    end

    context "with segment_id parameter" do
      let!(:vip_tag) { create(:subscriber_tag, site: site, name: "VIP", slug: "vip") }
      let!(:segment) do
        create(:subscriber_segment, site: site, name: "VIP Only", rules: {
          "tags" => { "any" => [ "vip" ] }
        })
      end

      let!(:vip_user) { create(:user) }
      let!(:vip_sub) { create(:digest_subscription, :due, user: vip_user, site: site, frequency: :weekly) }
      let!(:regular_user) { create(:user) }
      let!(:regular_sub) { create(:digest_subscription, :due, user: regular_user, site: site, frequency: :weekly) }

      before do
        create(:subscriber_tagging, digest_subscription: vip_sub, subscriber_tag: vip_tag)
      end

      it "sends only to subscribers matching the segment" do
        allow(DigestMailer).to receive(:weekly_digest).and_call_original

        described_class.perform_now(frequency: "weekly", segment_id: segment.id)

        expect(DigestMailer).to have_received(:weekly_digest).with(vip_sub)
      end

      it "does not send to subscribers not matching the segment" do
        allow(DigestMailer).to receive(:weekly_digest).and_call_original

        described_class.perform_now(frequency: "weekly", segment_id: segment.id)

        expect(DigestMailer).not_to have_received(:weekly_digest).with(regular_sub)
      end

      it "combines segment filtering with frequency filtering" do
        daily_vip_user = create(:user)
        daily_vip_sub = create(:digest_subscription, :due, user: daily_vip_user, site: site, frequency: :daily)
        create(:subscriber_tagging, digest_subscription: daily_vip_sub, subscriber_tag: vip_tag)

        allow(DigestMailer).to receive(:weekly_digest).and_call_original

        described_class.perform_now(frequency: "weekly", segment_id: segment.id)

        # Only weekly VIP subscribers should receive
        expect(DigestMailer).to have_received(:weekly_digest).with(vip_sub)
        expect(DigestMailer).not_to have_received(:weekly_digest).with(daily_vip_sub)
      end
    end

    context "with empty segment" do
      let!(:segment) do
        create(:subscriber_segment, site: site, name: "Empty Segment", rules: {
          "referral_count" => { "min" => 999 }
        })
      end
      let!(:user) { create(:user) }
      let!(:sub) { create(:digest_subscription, :due, user: user, site: site, frequency: :weekly) }

      it "logs a warning when segment has no matching subscribers" do
        allow(Rails.logger).to receive(:warn)

        described_class.perform_now(frequency: "weekly", segment_id: segment.id)

        expect(Rails.logger).to have_received(:warn).with(/has no matching subscribers/)
      end

      it "does not send any emails" do
        allow(DigestMailer).to receive(:weekly_digest).and_call_original

        described_class.perform_now(frequency: "weekly", segment_id: segment.id)

        expect(DigestMailer).not_to have_received(:weekly_digest)
      end
    end

    context "with non-existent segment_id" do
      let!(:user) { create(:user) }
      let!(:sub) { create(:digest_subscription, :due, user: user, site: site, frequency: :weekly) }

      it "sends to all subscribers when segment not found" do
        allow(DigestMailer).to receive(:weekly_digest).and_call_original

        described_class.perform_now(frequency: "weekly", segment_id: 99999)

        # Without segment, falls back to normal behavior
        expect(DigestMailer).to have_received(:weekly_digest).with(sub)
      end
    end

    context "without segment_id parameter" do
      let!(:user1) { create(:user) }
      let!(:user2) { create(:user) }
      let!(:sub1) { create(:digest_subscription, :due, user: user1, site: site, frequency: :weekly) }
      let!(:sub2) { create(:digest_subscription, :due, user: user2, site: site, frequency: :weekly) }

      it "sends to all due subscribers" do
        allow(DigestMailer).to receive(:weekly_digest).and_call_original

        described_class.perform_now(frequency: "weekly")

        expect(DigestMailer).to have_received(:weekly_digest).with(sub1)
        expect(DigestMailer).to have_received(:weekly_digest).with(sub2)
      end
    end
  end

  describe "queue configuration" do
    it "uses the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end

    it "can be enqueued" do
      expect {
        described_class.perform_later(frequency: "weekly")
      }.to have_enqueued_job(described_class)
    end

    it "accepts segment_id parameter when enqueued" do
      segment = create(:subscriber_segment, site: site, name: "Test")

      expect {
        described_class.perform_later(frequency: "weekly", segment_id: segment.id)
      }.to have_enqueued_job(described_class).with(frequency: "weekly", segment_id: segment.id)
    end
  end
end
