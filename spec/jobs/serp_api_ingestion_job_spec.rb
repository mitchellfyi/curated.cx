# frozen_string_literal: true

require "rails_helper"

RSpec.describe SerpApiIngestionJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :serp_api_google_news, site: site) }
  let(:serp_api_response) { fixture_file("serp_api_news.json") }

  describe "#perform" do
    context "happy path" do
      before do
        stub_serp_api_response
        # Stub the TaggingService to avoid dependency issues
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "creates ContentItems from SerpAPI results" do
        expect {
          described_class.perform_now(source.id)
        }.to change(ContentItem, :count).by(3)
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

      it "stores correct ContentItem attributes" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Tech News Article 1")
        expect(item).to be_present
        expect(item.url_raw).to eq("https://news.example.com/tech-1")
        expect(item.description).to eq("Breaking news about technology innovations.")
        expect(item.source).to eq(source)
        expect(item.site).to eq(site)
      end

      it "extracts tags from source info" do
        described_class.perform_now(source.id)

        # The fixture has source names like "Tech Daily"
        item = ContentItem.find_by(title: "Tech News Article 1")
        expect(item.tags).to include("source:tech-daily")
      end
    end

    context "deduplication" do
      before do
        stub_serp_api_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "does not create duplicate ContentItems on subsequent runs" do
        expect {
          described_class.perform_now(source.id)
        }.to change(ContentItem, :count).by(3)

        expect {
          described_class.perform_now(source.id)
        }.to change(ContentItem, :count).by(0)
      end

      it "updates existing ContentItems on subsequent runs" do
        described_class.perform_now(source.id)
        first_run = ImportRun.order(:created_at).last

        described_class.perform_now(source.id)
        second_run = ImportRun.order(:created_at).last

        expect(first_run.items_created).to eq(3)
        expect(first_run.items_updated).to eq(0)

        expect(second_run.items_created).to eq(0)
        expect(second_run.items_updated).to eq(3)
      end
    end

    context "max_results configuration" do
      let(:source) do
        create(:source, :serp_api_google_news, site: site, config: {
          "api_key" => "test_api_key",
          "query" => "test",
          "max_results" => 2
        })
      end

      before do
        stub_serp_api_response
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
        }.to change(ContentItem, :count).by(2)
      end
    end

    context "rate limiting" do
      before do
        # Create 10 import runs in the last hour to hit the rate limit
        10.times do
          create(:import_run, source: source, started_at: 30.minutes.ago)
        end
      end

      it "skips processing when rate limited" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ContentItem, :count)
      end

      it "does not create an ImportRun when rate limited" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ImportRun, :count)
      end

      it "updates source status to rate_limited" do
        described_class.perform_now(source.id)
        source.reload
        expect(source.last_status).to eq("rate_limited")
      end
    end

    context "when source is disabled" do
      let(:source) { create(:source, :serp_api_google_news, :disabled, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ContentItem, :count)

        source.reload
        expect(source.last_status).to eq("skipped")
      end

      it "does not create an ImportRun" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ImportRun, :count)
      end
    end

    context "when source is not serp_api_google_news type" do
      let(:source) { create(:source, :rss, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ContentItem, :count)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when API key is not configured" do
      let(:source) do
        create(:source, :serp_api_google_news, site: site, config: { "query" => "test" })
      end

      it "marks the ImportRun as failed" do
        # Note: ConfigurationError may trigger retry mechanism, so we catch any error
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - discard_on or retry mechanism may throw
        end

        import_run = ImportRun.last
        expect(import_run&.status).to eq("failed")
        expect(import_run&.error_message).to include("SerpAPI key not configured")
      end

      it "updates source status with error" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - discard_on or retry mechanism may throw
        end

        source.reload
        expect(source.last_status).to start_with("error:")
      end
    end

    context "when SerpAPI request fails" do
      before do
        stub_request(:get, /serpapi\.com\/search\.json/)
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "updates source status with HTTP error" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - retry mechanism may throw
        end

        source.reload
        expect(source.last_status).to include("500")
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

    context "when news_results is empty" do
      before do
        stub_request(:get, /serpapi\.com\/search\.json/)
          .to_return(
            status: 200,
            body: { "news_results" => [] }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "handles empty results gracefully" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ContentItem, :count)

        source.reload
        expect(source.last_status).to eq("success")
      end

      it "marks ImportRun as completed with zero counts" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.status).to eq("completed")
        expect(import_run.items_count).to eq(0)
      end
    end

    context "when news_results is missing" do
      before do
        stub_request(:get, /serpapi\.com\/search\.json/)
          .to_return(
            status: 200,
            body: { "search_metadata" => { "status" => "Success" } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "handles missing news_results gracefully" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ContentItem, :count)

        source.reload
        expect(source.last_status).to eq("success")
      end
    end

    context "uses config parameters" do
      before do
        stub_serp_api_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "sends correct parameters to SerpAPI" do
        described_class.perform_now(source.id)

        expect(WebMock).to have_requested(:get, /serpapi\.com\/search\.json/)
          .with(query: hash_including(
            "engine" => "google_news",
            "api_key" => "test_api_key",
            "q" => "AI news",
            "location" => "United States",
            "hl" => "en"
          ))
      end
    end

    context "tenant context management" do
      before do
        stub_serp_api_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "sets Current.tenant during execution" do
        described_class.perform_now(source.id)

        # Verify the job ran successfully (requires tenant context)
        import_run = ImportRun.last
        expect(import_run.status).to eq("completed")
      end

      it "clears context after execution" do
        described_class.perform_now(source.id)

        expect(Current.tenant).to be_nil
        expect(Current.site).to be_nil
      end
    end

    context "handling individual item failures" do
      before do
        # Return response with an invalid URL
        invalid_response = {
          "news_results" => [
            { "title" => "Good Article", "link" => "https://example.com/good", "snippet" => "Good" },
            { "title" => "Bad Article", "link" => "not-a-valid-url", "snippet" => "Bad" },
            { "title" => "Another Good", "link" => "https://example.com/good2", "snippet" => "Good" }
          ]
        }.to_json

        stub_request(:get, /serpapi\.com\/search\.json/)
          .to_return(status: 200, body: invalid_response, headers: { "Content-Type" => "application/json" })

        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "marks overall run as completed (not failed)" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.status).to eq("completed")
      end
    end

    context "handling results without links" do
      before do
        response = {
          "news_results" => [
            { "title" => "No Link Article", "snippet" => "Description" },
            { "title" => "Good Article", "link" => "https://example.com/good", "snippet" => "Good" }
          ]
        }.to_json

        stub_request(:get, /serpapi\.com\/search\.json/)
          .to_return(status: 200, body: response, headers: { "Content-Type" => "application/json" })

        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "skips results without URLs and completes" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.status).to eq("completed")
      end
    end
  end

  describe "retry behavior" do
    it "is configured to retry on StandardError" do
      error_classes = described_class.rescue_handlers.map { |h| h[0] }
      expect(error_classes).to include("StandardError")
    end
  end

  describe "queue configuration" do
    it "uses the ingestion queue" do
      expect(described_class.queue_name).to eq("ingestion")
    end
  end
end
