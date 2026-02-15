# frozen_string_literal: true

require "rails_helper"

RSpec.describe AffiliateService do
  describe ".eligible?" do
    it "returns true for Amazon URLs" do
      expect(described_class.eligible?("https://www.amazon.com/dp/B08N5WRWNW")).to be true
    end

    it "returns true for Amazon regional domains" do
      expect(described_class.eligible?("https://www.amazon.co.uk/product")).to be true
      expect(described_class.eligible?("https://www.amazon.de/product")).to be true
    end

    it "returns true for known Impact merchants" do
      expect(described_class.eligible?("https://www.notion.so/pricing")).to be true
      expect(described_class.eligible?("https://www.canva.com/tools")).to be true
    end

    it "returns false for unknown URLs" do
      expect(described_class.eligible?("https://www.example.com")).to be false
    end

    it "returns false for blank URLs" do
      expect(described_class.eligible?("")).to be false
      expect(described_class.eligible?(nil)).to be false
    end
  end

  describe ".detect_network" do
    it "detects Amazon" do
      expect(described_class.detect_network("https://www.amazon.com/dp/B08N5WRWNW")).to eq("amazon")
    end

    it "detects Impact" do
      expect(described_class.detect_network("https://www.notion.so/pricing")).to eq("impact")
    end

    it "detects ShareASale" do
      expect(described_class.detect_network("https://tailwindcss.com/docs")).to eq("shareasale")
    end

    it "detects CJ" do
      expect(described_class.detect_network("https://www.godaddy.com")).to eq("cj")
    end

    it "detects Awin" do
      expect(described_class.detect_network("https://www.etsy.com/listing/123")).to eq("awin")
    end

    it "detects PartnerStack" do
      expect(described_class.detect_network("https://www.intercom.com")).to eq("partnerstack")
    end

    it "returns nil for unknown domains" do
      expect(described_class.detect_network("https://example.com")).to be_nil
    end
  end

  describe ".process_url" do
    it "returns affiliate info for eligible URLs" do
      result = described_class.process_url("https://www.amazon.com/dp/B08N5WRWNW")
      expect(result).to eq({
        network: "amazon",
        eligible: true,
        original_url: "https://www.amazon.com/dp/B08N5WRWNW"
      })
    end

    it "returns nil for ineligible URLs" do
      expect(described_class.process_url("https://example.com")).to be_nil
    end
  end

  describe ".scan_entry" do
    let(:tenant) { create(:tenant) }
    let(:category) { create(:category, tenant: tenant) }

    it "updates entry affiliate fields for eligible URLs" do
      entry = create(:entry, :directory, tenant: tenant, category: category,
                     url_raw: "https://www.amazon.com/dp/B08N5WRWNW",
                     url_canonical: "https://www.amazon.com/dp/B08N5WRWNW")
      described_class.scan_entry(entry)
      entry.reload
      expect(entry.affiliate_eligible).to be true
      expect(entry.affiliate_network).to eq("amazon")
    end

    it "marks entry as not eligible for unknown URLs" do
      entry = create(:entry, :directory, tenant: tenant, category: category,
                     url_raw: "https://example.com",
                     url_canonical: "https://example.com")
      described_class.scan_entry(entry)
      entry.reload
      expect(entry.affiliate_eligible).to be false
      expect(entry.affiliate_network).to be_nil
    end
  end
end
