# frozen_string_literal: true

require "rails_helper"

RSpec.describe NetworkBoostService do
  let(:tenant) { create(:tenant, :enabled) }
  let(:display_site) { create(:site, tenant: tenant) }
  let(:source_site) { create(:site, tenant: tenant) }
  let(:target_site) { display_site }
  let(:user) { create(:user) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(display_site)
  end

  describe ".for_site" do
    context "when site has boosts display disabled" do
      before do
        allow(display_site).to receive(:boosts_display_enabled?).and_return(false)
      end

      it "returns empty array" do
        expect(described_class.for_site(display_site)).to eq([])
      end
    end

    context "when site has boosts display enabled" do
      before do
        allow(display_site).to receive(:boosts_display_enabled?).and_return(true)
      end

      it "returns enabled boosts targeting this site" do
        boost = create(:network_boost, source_site: source_site, target_site: display_site, enabled: true)

        result = described_class.for_site(display_site)

        expect(result).to include(boost)
      end

      it "excludes disabled boosts" do
        boost = create(:network_boost, source_site: source_site, target_site: display_site, enabled: false)

        result = described_class.for_site(display_site)

        expect(result).not_to include(boost)
      end

      it "excludes boosts over budget" do
        boost = create(:network_boost, source_site: source_site, target_site: display_site, monthly_budget: 100, spent_this_month: 100)

        result = described_class.for_site(display_site)

        expect(result).not_to include(boost)
      end

      it "excludes boosts where the display site is the source" do
        another_target = create(:site, tenant: tenant)
        boost = create(:network_boost, source_site: display_site, target_site: another_target)

        result = described_class.for_site(display_site)

        expect(result).not_to include(boost)
      end

      it "excludes sites user is already subscribed to" do
        subscription = create(:digest_subscription, user: user, site: source_site, active: true)
        boost = create(:network_boost, source_site: source_site, target_site: display_site)

        result = described_class.for_site(display_site, user: user)

        expect(result).not_to include(boost)
      end

      it "includes boosts for sites user is not subscribed to" do
        boost = create(:network_boost, source_site: source_site, target_site: display_site)

        result = described_class.for_site(display_site, user: user)

        expect(result).to include(boost)
      end

      it "orders by cpc_rate descending (highest first)" do
        low_cpc = create(:network_boost, source_site: source_site, target_site: display_site, cpc_rate: 0.25)
        another_source = create(:site, tenant: tenant)
        high_cpc = create(:network_boost, source_site: another_source, target_site: display_site, cpc_rate: 1.00)

        result = described_class.for_site(display_site)

        expect(result.first).to eq(high_cpc)
        expect(result.last).to eq(low_cpc)
      end

      it "respects the limit parameter" do
        3.times do |i|
          site = create(:site, tenant: tenant)
          create(:network_boost, source_site: site, target_site: display_site, cpc_rate: i + 1)
        end

        result = described_class.for_site(display_site, limit: 2)

        expect(result.count).to eq(2)
      end
    end
  end

  describe ".available_targets" do
    it "returns enabled sites except the given site" do
      other_site = create(:site, tenant: tenant)

      result = described_class.available_targets(display_site)

      expect(result).to include(other_site)
      expect(result).not_to include(display_site)
    end

    it "excludes sites that already have a boost" do
      other_site = create(:site, tenant: tenant)
      create(:network_boost, source_site: display_site, target_site: other_site)

      result = described_class.available_targets(display_site)

      expect(result).not_to include(other_site)
    end

    it "excludes disabled sites" do
      other_site = create(:site, tenant: tenant)
      other_site.update!(status: :disabled)

      result = described_class.available_targets(display_site)

      expect(result).not_to include(other_site)
    end

    it "respects the limit parameter" do
      5.times { create(:site, tenant: tenant) }

      result = described_class.available_targets(display_site, limit: 3)

      expect(result.count).to eq(3)
    end
  end

  describe ".record_impression" do
    let(:boost) { create(:network_boost, source_site: source_site, target_site: display_site) }

    it "creates a boost impression" do
      expect {
        described_class.record_impression(boost: boost, site: display_site, ip: "192.168.1.1")
      }.to change(BoostImpression, :count).by(1)
    end

    it "sets the correct attributes" do
      impression = described_class.record_impression(boost: boost, site: display_site, ip: "192.168.1.1")

      expect(impression.network_boost).to eq(boost)
      expect(impression.site).to eq(display_site)
      expect(impression.ip_hash).to be_present
      expect(impression.shown_at).to be_present
    end

    it "hashes the IP address" do
      impression = described_class.record_impression(boost: boost, site: display_site, ip: "192.168.1.1")

      expect(impression.ip_hash).not_to eq("192.168.1.1")
      expect(impression.ip_hash.length).to eq(64) # SHA256 hex length
    end
  end

  describe ".record_impressions" do
    let(:boost1) { create(:network_boost, source_site: source_site, target_site: display_site) }
    let(:boost2) do
      another_source = create(:site, tenant: tenant)
      create(:network_boost, source_site: another_source, target_site: display_site)
    end

    it "creates impressions for all boosts" do
      expect {
        described_class.record_impressions(boosts: [ boost1, boost2 ], site: display_site, ip: "192.168.1.1")
      }.to change(BoostImpression, :count).by(2)
    end

    it "does nothing when boosts array is empty" do
      expect {
        described_class.record_impressions(boosts: [], site: display_site, ip: "192.168.1.1")
      }.not_to change(BoostImpression, :count)
    end

    it "uses the same ip_hash and shown_at for all impressions" do
      described_class.record_impressions(boosts: [ boost1, boost2 ], site: display_site, ip: "192.168.1.1")

      impressions = BoostImpression.last(2)
      expect(impressions.map(&:ip_hash).uniq.count).to eq(1)
    end
  end
end
