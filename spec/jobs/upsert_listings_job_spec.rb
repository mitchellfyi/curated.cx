# frozen_string_literal: true

require "rails_helper"

RSpec.describe UpsertListingsJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:category) { create(:category, tenant: tenant, site: site) }
  let(:source) { create(:source, :rss, site: site) }
  let(:url_raw) { "https://example.com/article-1?utm_source=test" }

  describe "#perform" do
    context "happy path - new listing" do
      it "creates a new listing with correct attributes" do
        expect {
          described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)
        }.to change(Listing, :count).by(1)
      end

      it "sets listing attributes correctly" do
        listing = described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)

        expect(listing.tenant).to eq(tenant)
        expect(listing.site).to eq(site)
        expect(listing.category).to eq(category)
        expect(listing.source).to eq(source)
        expect(listing.url_raw).to eq(url_raw)
      end

      it "canonicalizes URL and removes tracking params" do
        listing = described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)

        expect(listing.url_canonical).to eq("https://example.com/article-1")
        expect(listing.url_canonical).not_to include("utm_source")
      end

      it "enqueues ScrapeMetadataJob after creating listing" do
        expect {
          described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)
        }.to have_enqueued_job(ScrapeMetadataJob).once
      end

      it "extracts basic title from URL" do
        listing = described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)

        expect(listing.title).to be_present
        expect(listing.title).not_to eq("Untitled")
      end
    end

    context "idempotency - existing listing" do
      let!(:existing_listing) do
        create(:listing,
          tenant: tenant,
          site: site,
          category: category,
          url_raw: url_raw,
          url_canonical: "https://example.com/article-1")
      end

      it "does not create duplicate listing" do
        expect {
          described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)
        }.not_to change(Listing, :count)
      end

      it "returns existing listing" do
        result = described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)

        expect(result.id).to eq(existing_listing.id)
      end

      it "does NOT enqueue ScrapeMetadataJob for existing listing" do
        expect {
          described_class.perform_now(tenant.id, category.id, url_raw, source_id: source.id)
        }.not_to have_enqueued_job(ScrapeMetadataJob)
      end

      it "updates source if provided" do
        new_source = create(:source, :rss, site: site, name: "New Source")

        described_class.perform_now(tenant.id, category.id, url_raw, source_id: new_source.id)

        existing_listing.reload
        expect(existing_listing.source).to eq(new_source)
      end
    end

    context "URL normalization" do
      it "treats different URLs with same canonical as duplicates" do
        # First with tracking params
        listing1 = described_class.perform_now(tenant.id, category.id, "https://example.com/page?utm_source=a")
        # Second with different tracking params
        listing2 = described_class.perform_now(tenant.id, category.id, "https://example.com/page?utm_campaign=b")

        expect(listing2.id).to eq(listing1.id)
      end

      it "normalizes case in host" do
        listing = described_class.perform_now(tenant.id, category.id, "https://EXAMPLE.COM/page")

        expect(listing.url_canonical).to eq("https://example.com/page")
      end
    end

    context "invalid URL" do
      it "returns nil for blank URL" do
        result = described_class.perform_now(tenant.id, category.id, "")

        expect(result).to be_nil
      end

      it "logs warning and returns nil for invalid URL" do
        expect(Rails.logger).to receive(:warn).with(/Invalid URL/)

        result = described_class.perform_now(tenant.id, category.id, "not a valid url at all")

        expect(result).to be_nil
      end

      it "does not raise error for invalid URL" do
        expect {
          described_class.perform_now(tenant.id, category.id, "invalid://url")
        }.not_to raise_error
      end
    end

    context "validation errors" do
      it "raises error when category belongs to different site" do
        other_site = create(:site, tenant: tenant)
        other_category = create(:category, tenant: tenant, site: other_site)

        expect {
          described_class.perform_now(tenant.id, other_category.id, url_raw)
        }.to raise_error("Site tenant mismatch")
      end
    end

    context "without source_id" do
      it "creates listing without source" do
        listing = described_class.perform_now(tenant.id, category.id, url_raw)

        expect(listing.source).to be_nil
      end
    end

    context "tenant context management" do
      it "sets Current.tenant during execution" do
        expect(Current).to receive(:tenant=).with(tenant).ordered
        expect(Current).to receive(:site=).with(site).ordered
        expect(Current).to receive(:tenant=).with(nil).ordered
        expect(Current).to receive(:site=).with(nil).ordered

        described_class.perform_now(tenant.id, category.id, url_raw)
      end

      it "clears context even when error occurs" do
        expect(Current).to receive(:tenant=).with(nil).at_least(:once)
        expect(Current).to receive(:site=).with(nil).at_least(:once)

        begin
          # Invalid category ID will cause error
          described_class.perform_now(tenant.id, -1, url_raw)
        rescue StandardError
          # Expected
        end
      end
    end

    context "race condition handling" do
      # Simulate race condition where two jobs try to create same listing
      it "handles ActiveRecord::RecordNotUnique by finding existing" do
        # First create succeeds
        listing1 = described_class.perform_now(tenant.id, category.id, url_raw)

        # Simulate second job finding the same record after retry
        expect(Listing).to receive(:find_by).with(site: site, url_canonical: anything)
          .and_return(nil)
          .ordered
        expect(Listing).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
        expect(Listing).to receive(:find_by).with(site: site, url_canonical: anything)
          .and_return(listing1)
          .ordered

        result = described_class.perform_now(tenant.id, category.id, "https://example.com/article-1")

        expect(result.id).to eq(listing1.id)
      end
    end
  end

  describe "retry behavior" do
    it "retries on ActiveRecord::RecordNotUnique" do
      expect(described_class.rescue_handlers).to include(
        a_hash_including("error_class" => "ActiveRecord::RecordNotUnique")
      )
    end

    it "retries on StandardError" do
      expect(described_class.rescue_handlers).to include(
        a_hash_including("error_class" => "StandardError")
      )
    end

    it "retries RecordNotUnique 5 times" do
      handler = described_class.rescue_handlers.find { |h| h["error_class"] == "ActiveRecord::RecordNotUnique" }
      expect(handler["attempts"]).to eq(5)
    end

    it "retries StandardError 3 times" do
      handler = described_class.rescue_handlers.find { |h| h["error_class"] == "StandardError" }
      expect(handler["attempts"]).to eq(3)
    end
  end

  describe "queue configuration" do
    it "uses the ingestion queue" do
      expect(described_class.queue_name).to eq("ingestion")
    end
  end
end
