# frozen_string_literal: true

require "rails_helper"

RSpec.describe SerpApiGoogleShoppingIngestionJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :google_shopping, site: site) }

  describe "#perform" do
    context "happy path" do
      before do
        stub_google_shopping_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "creates Entrys from Google Shopping results" do
        expect {
          described_class.perform_now(source.id)
        }.to change(Entry, :count).by(3)
      end

      it "creates an ImportRun record" do
        expect {
          described_class.perform_now(source.id)
        }.to change(ImportRun, :count).by(1)
      end

      it "marks the ImportRun as completed" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.status).to eq("completed")
        expect(import_run.completed_at).to be_present
      end

      it "tracks item counts in the ImportRun" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.items_created).to eq(3)
        expect(import_run.items_updated).to eq(0)
        expect(import_run.items_failed).to eq(0)
        expect(import_run.items_count).to eq(3)
      end

      it "updates source status to success" do
        described_class.perform_now(source.id)
        source.reload
        expect(source.last_status).to eq("success")
        expect(source.last_run_at).to be_within(1.second).of(Time.current)
      end

      it "stores correct Entry attributes" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones")
        expect(item).to be_present
        expect(item.url_raw).to include("example.com/product/sony-wh1000xm5")
        expect(item.og_image_url).to eq("https://encrypted-tbn0.gstatic.com/shopping?q=tbn:sony_xm5")
        expect(item.source).to eq(source)
        expect(item.site).to eq(site)
      end

      it "stores price in raw_payload" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones")
        expect(item.raw_payload.dig("_shopping_metadata", "price")).to eq("£279.00")
      end

      it "stores extracted_price in raw_payload" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones")
        expect(item.raw_payload.dig("_shopping_metadata", "extracted_price")).to eq(279.0)
      end

      it "stores rating in raw_payload" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones")
        expect(item.raw_payload.dig("_shopping_metadata", "rating")).to eq(4.6)
      end

      it "stores review count in raw_payload" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones")
        expect(item.raw_payload.dig("_shopping_metadata", "review_count")).to eq(12543)
      end

      it "stores merchant in raw_payload" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones")
        expect(item.raw_payload.dig("_shopping_metadata", "merchant")).to eq("Amazon")
      end

      it "stores product_id in raw_payload" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones")
        expect(item.raw_payload.dig("_shopping_metadata", "product_id")).to eq("123456")
      end

      it "tags products correctly with source and merchant" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "Sony WH-1000XM5 Wireless Noise Cancelling Headphones")
        expect(item.tags).to include("source:google_shopping")
        expect(item.tags).to include("merchant:amazon")
      end

      it "handles products without thumbnails" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "JBL Tune 510BT On-Ear Wireless Headphones")
        expect(item.og_image_url).to be_nil
      end

      it "handles products without ratings" do
        described_class.perform_now(source.id)

        item = Entry.find_by(title: "JBL Tune 510BT On-Ear Wireless Headphones")
        expect(item.raw_payload.dig("_shopping_metadata", "rating")).to be_nil
      end
    end

    context "location configuration" do
      let(:source) do
        create(:source, :google_shopping, site: site, config: {
          "api_key" => "test_api_key",
          "query" => "wireless headphones",
          "location" => "United Kingdom",
          "gl" => "uk"
        })
      end

      before do
        stub_google_shopping_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "sends location and gl parameters to SerpAPI" do
        described_class.perform_now(source.id)

        expect(WebMock).to have_requested(:get, /serpapi\.com\/search\.json/)
          .with(query: hash_including(
            "engine" => "google_shopping",
            "location" => "United Kingdom",
            "gl" => "uk"
          ))
      end
    end

    context "deduplication" do
      before do
        stub_google_shopping_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "does not create duplicate Entrys on subsequent runs" do
        expect {
          described_class.perform_now(source.id)
        }.to change(Entry, :count).by(3)

        expect {
          described_class.perform_now(source.id)
        }.to change(Entry, :count).by(0)
      end
    end

    context "max_results configuration" do
      let(:source) do
        create(:source, :google_shopping, site: site, config: {
          "api_key" => "test_api_key",
          "query" => "wireless headphones",
          "max_results" => 2
        })
      end

      before do
        stub_google_shopping_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "respects max_results limit" do
        expect {
          described_class.perform_now(source.id)
        }.to change(Entry, :count).by(2)
      end
    end

    context "when source is disabled" do
      let(:source) { create(:source, :google_shopping, :disabled, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(Entry, :count)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when source is not google_shopping type" do
      let(:source) { create(:source, :rss, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(Entry, :count)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when API key is not configured" do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:serpapi, :api_key).and_return(nil)
      end

      let(:source) do
        create(:source, :google_shopping, site: site, config: { "query" => "test" })
      end

      it "marks the ImportRun as failed" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - retry mechanism may throw
        end

        import_run = ImportRun.last
        expect(import_run&.status).to eq("failed")
        expect(import_run&.error_message).to include("SerpAPI key not configured")
      end
    end

    context "when search query is not configured" do
      let(:source) do
        create(:source, :google_shopping, site: site, config: { "api_key" => "test_key" })
      end

      it "marks the ImportRun as failed" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - retry mechanism may throw
        end

        import_run = ImportRun.last
        expect(import_run&.status).to eq("failed")
        expect(import_run&.error_message).to include("Search query not configured")
      end
    end

    context "when SerpAPI request fails" do
      before do
        stub_request(:get, /serpapi\.com\/search\.json/)
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "marks the ImportRun as failed" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - retry mechanism may throw
        end

        import_run = ImportRun.last
        expect(import_run.status).to eq("failed")
        expect(import_run.error_message).to include("500")
      end
    end

    context "when shopping_results is empty" do
      before do
        stub_request(:get, /serpapi\.com\/search\.json/)
          .to_return(
            status: 200,
            body: { "shopping_results" => [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "handles empty results gracefully" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(Entry, :count)

        source.reload
        expect(source.last_status).to eq("success")
      end
    end
  end

  describe "queue configuration" do
    it "uses the ingestion queue" do
      expect(described_class.queue_name).to eq("ingestion")
    end
  end
end
