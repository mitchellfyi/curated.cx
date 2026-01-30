# frozen_string_literal: true

require "rails_helper"

RSpec.describe BoostAttributionService do
  let(:tenant) { create(:tenant, :enabled) }
  let(:source_site) { create(:site, tenant: tenant) }
  let(:target_site) { create(:site, tenant: tenant) }
  let(:boost) { create(:network_boost, source_site: source_site, target_site: target_site, cpc_rate: 0.50) }
  let(:user) { create(:user) }
  let(:subscription) { create(:digest_subscription, user: user, site: target_site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(target_site)
  end

  describe ".record_click" do
    it "creates a boost click" do
      expect {
        described_class.record_click(boost: boost, ip: "192.168.1.1")
      }.to change(BoostClick, :count).by(1)
    end

    it "sets correct attributes on the click" do
      click = described_class.record_click(boost: boost, ip: "192.168.1.1")

      expect(click.network_boost).to eq(boost)
      expect(click.ip_hash).to be_present
      expect(click.clicked_at).to be_present
      expect(click.earned_amount).to eq(boost.cpc_rate)
      expect(click.status).to eq("pending")
    end

    it "hashes the IP address" do
      click = described_class.record_click(boost: boost, ip: "192.168.1.1")

      expect(click.ip_hash).not_to eq("192.168.1.1")
      expect(click.ip_hash.length).to eq(64)
    end

    it "updates boost spending" do
      expect {
        described_class.record_click(boost: boost, ip: "192.168.1.1")
      }.to change { boost.reload.spent_this_month }.by(0.50)
    end

    it "schedules confirmation job for 24 hours later" do
      expect {
        described_class.record_click(boost: boost, ip: "192.168.1.1")
      }.to have_enqueued_job(ConfirmBoostClickJob)
    end

    context "when same IP clicked within 24 hours" do
      before do
        described_class.record_click(boost: boost, ip: "192.168.1.1")
      end

      it "returns nil (deduplication)" do
        result = described_class.record_click(boost: boost, ip: "192.168.1.1")
        expect(result).to be_nil
      end

      it "does not create another click" do
        expect {
          described_class.record_click(boost: boost, ip: "192.168.1.1")
        }.not_to change(BoostClick, :count)
      end
    end

    context "when same IP clicked more than 24 hours ago" do
      before do
        create(:boost_click, network_boost: boost, ip_hash: described_class.send(:hash_ip, "192.168.1.1"), clicked_at: 25.hours.ago)
      end

      it "creates a new click" do
        expect {
          described_class.record_click(boost: boost, ip: "192.168.1.1")
        }.to change(BoostClick, :count).by(1)
      end
    end
  end

  describe ".attribute_conversion" do
    context "when there is an attributable click" do
      let!(:click) do
        create(:boost_click,
               network_boost: boost,
               ip_hash: Digest::SHA256.hexdigest("192.168.1.1:#{Rails.application.secret_key_base}"),
               clicked_at: 10.days.ago,
               converted_at: nil)
      end

      it "marks the click as converted" do
        result = described_class.attribute_conversion(subscription: subscription, ip: "192.168.1.1")

        expect(result).to eq(click)
        expect(click.reload.converted_at).to be_present
        expect(click.digest_subscription).to eq(subscription)
      end

      it "returns the click" do
        result = described_class.attribute_conversion(subscription: subscription, ip: "192.168.1.1")
        expect(result).to eq(click)
      end
    end

    context "when click is outside attribution window (30 days)" do
      before do
        create(:boost_click,
               network_boost: boost,
               ip_hash: Digest::SHA256.hexdigest("192.168.1.1:#{Rails.application.secret_key_base}"),
               clicked_at: 35.days.ago,
               converted_at: nil)
      end

      it "returns nil" do
        result = described_class.attribute_conversion(subscription: subscription, ip: "192.168.1.1")
        expect(result).to be_nil
      end
    end

    context "when click is already converted" do
      before do
        other_subscription = create(:digest_subscription, site: target_site)
        create(:boost_click,
               network_boost: boost,
               ip_hash: Digest::SHA256.hexdigest("192.168.1.1:#{Rails.application.secret_key_base}"),
               clicked_at: 10.days.ago,
               converted_at: 5.days.ago,
               digest_subscription: other_subscription)
      end

      it "returns nil" do
        result = described_class.attribute_conversion(subscription: subscription, ip: "192.168.1.1")
        expect(result).to be_nil
      end
    end

    context "when there is no matching click" do
      it "returns nil" do
        result = described_class.attribute_conversion(subscription: subscription, ip: "192.168.1.1")
        expect(result).to be_nil
      end
    end

    context "when IP is nil" do
      it "returns nil" do
        result = described_class.attribute_conversion(subscription: subscription, ip: nil)
        expect(result).to be_nil
      end
    end

    context "with multiple unconverted clicks" do
      let!(:old_click) do
        create(:boost_click,
               network_boost: boost,
               ip_hash: Digest::SHA256.hexdigest("192.168.1.1:#{Rails.application.secret_key_base}"),
               clicked_at: 15.days.ago,
               converted_at: nil)
      end

      let!(:recent_click) do
        create(:boost_click,
               network_boost: boost,
               ip_hash: Digest::SHA256.hexdigest("192.168.1.1:#{Rails.application.secret_key_base}"),
               clicked_at: 5.days.ago,
               converted_at: nil)
      end

      it "attributes to the most recent click" do
        result = described_class.attribute_conversion(subscription: subscription, ip: "192.168.1.1")

        expect(result).to eq(recent_click)
        expect(old_click.reload.converted_at).to be_nil
      end
    end
  end

  describe ".calculate_earnings" do
    it "sums confirmed and paid clicks where site is the source" do
      create(:boost_click, :confirmed, network_boost: boost, earned_amount: 0.50, clicked_at: 5.days.ago)
      create(:boost_click, :paid, network_boost: boost, earned_amount: 0.75, clicked_at: 3.days.ago)
      create(:boost_click, :pending, network_boost: boost, earned_amount: 0.50, clicked_at: 1.day.ago)

      result = described_class.calculate_earnings(
        site: source_site,
        start_date: 7.days.ago,
        end_date: Time.current
      )

      expect(result).to eq(1.25)
    end

    it "excludes clicks outside the date range" do
      create(:boost_click, :confirmed, network_boost: boost, earned_amount: 0.50, clicked_at: 10.days.ago)

      result = described_class.calculate_earnings(
        site: source_site,
        start_date: 7.days.ago,
        end_date: Time.current
      )

      expect(result).to eq(0)
    end
  end

  describe ".calculate_spend" do
    it "sums confirmed and paid clicks where site is the target" do
      create(:boost_click, :confirmed, network_boost: boost, earned_amount: 0.50, clicked_at: 5.days.ago)
      create(:boost_click, :paid, network_boost: boost, earned_amount: 0.75, clicked_at: 3.days.ago)
      create(:boost_click, :pending, network_boost: boost, earned_amount: 0.50, clicked_at: 1.day.ago)

      result = described_class.calculate_spend(
        site: target_site,
        start_date: 7.days.ago,
        end_date: Time.current
      )

      expect(result).to eq(1.25)
    end
  end

  describe ".boost_stats" do
    before do
      3.times { create(:boost_impression, network_boost: boost, site: target_site, shown_at: 5.days.ago) }
      create(:boost_click, network_boost: boost, clicked_at: 5.days.ago, converted_at: nil, earned_amount: 0.50)
      create(:boost_click, network_boost: boost, clicked_at: 5.days.ago, converted_at: 4.days.ago, earned_amount: 0.50)
    end

    it "returns comprehensive stats" do
      stats = described_class.boost_stats(boost)

      expect(stats[:impressions]).to eq(3)
      expect(stats[:clicks]).to eq(2)
      expect(stats[:conversions]).to eq(1)
      expect(stats[:click_rate]).to eq(66.67)
      expect(stats[:conversion_rate]).to eq(50.0)
      expect(stats[:earnings]).to eq(1.0)
    end

    it "respects the since parameter" do
      create(:boost_impression, network_boost: boost, site: target_site, shown_at: 40.days.ago)
      create(:boost_click, network_boost: boost, clicked_at: 40.days.ago, earned_amount: 0.50)

      stats = described_class.boost_stats(boost, since: 30.days.ago)

      expect(stats[:impressions]).to eq(3)
      expect(stats[:clicks]).to eq(2)
    end

    it "handles zero impressions" do
      another_source = create(:site, tenant: tenant)
      boost_without_impressions = create(:network_boost, source_site: another_source, target_site: target_site)

      stats = described_class.boost_stats(boost_without_impressions)

      expect(stats[:click_rate]).to eq(0)
    end

    it "handles zero clicks" do
      yet_another_source = create(:site, tenant: tenant)
      boost_without_clicks = create(:network_boost, source_site: yet_another_source, target_site: target_site)

      stats = described_class.boost_stats(boost_without_clicks)

      expect(stats[:conversion_rate]).to eq(0)
    end
  end
end
