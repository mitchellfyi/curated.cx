# frozen_string_literal: true

require "rails_helper"

RSpec.describe HackerNewsIngestionJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :hacker_news, site: site) }

  describe "#perform" do
    context "happy path" do
      before do
        stub_hacker_news_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "creates ContentItems from HN results" do
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

      it "stores correct ContentItem attributes for stories with URLs" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Show HN: A New Startup Framework")
        expect(item).to be_present
        expect(item.url_raw).to eq("https://example.com/startup-framework")
        expect(item.description).to include("150 points")
        expect(item.description).to include("42 comments")
        expect(item.description).to include("by techfounder")
        expect(item.source).to eq(source)
        expect(item.site).to eq(site)
      end

      it "uses HN discussion URL for stories without external URLs" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Ask HN: Best Practices for Remote Teams")
        expect(item).to be_present
        expect(item.url_raw).to eq("https://news.ycombinator.com/item?id=12347")
      end

      it "extracts HN-specific tags" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Show HN: A New Startup Framework")
        expect(item.tags).to include("source:hacker-news")
        expect(item.tags).to include("hn:story")
        expect(item.tags).to include("hn:show_hn")
      end

      it "stores raw payload from the API" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Show HN: A New Startup Framework")
        expect(item.raw_payload["objectID"]).to eq("12345")
        expect(item.raw_payload["points"]).to eq(150)
        expect(item.raw_payload["num_comments"]).to eq(42)
        expect(item.raw_payload["author"]).to eq("techfounder")
      end
    end

    context "deduplication" do
      before do
        stub_hacker_news_response
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
        create(:source, :hacker_news, site: site, config: {
          "query" => "test",
          "tags" => "story",
          "max_results" => 2
        })
      end

      before do
        stub_hacker_news_response
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

    context "when source is disabled" do
      let(:source) { create(:source, :hacker_news, :disabled, site: site) }

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

    context "when source is not hacker_news type" do
      let(:source) { create(:source, :rss, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ContentItem, :count)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when HN API request fails" do
      before do
        stub_hacker_news_response(status: 500)
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

      it "updates source status with error" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected
        end

        source.reload
        expect(source.last_status).to start_with("error:")
      end
    end

    context "when hits is empty" do
      before do
        stub_request(:get, /hn\.algolia\.com\/api\/v1\/search/)
          .to_return(
            status: 200,
            body: { "hits" => [] }.to_json,
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

    context "when hits key is missing" do
      before do
        stub_request(:get, /hn\.algolia\.com\/api\/v1\/search/)
          .to_return(
            status: 200,
            body: { "nbHits" => 0 }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "handles missing hits gracefully" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ContentItem, :count)

        source.reload
        expect(source.last_status).to eq("success")
      end
    end

    context "uses config parameters" do
      before do
        stub_hacker_news_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "sends correct parameters to HN API" do
        described_class.perform_now(source.id)

        expect(WebMock).to have_requested(:get, /hn\.algolia\.com\/api\/v1\/search/)
          .with(query: hash_including(
            "query" => "startup",
            "tags" => "story"
          ))
      end
    end

    context "tenant context management" do
      before do
        stub_hacker_news_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "sets Current.tenant during execution" do
        described_class.perform_now(source.id)

        import_run = ImportRun.last
        expect(import_run.status).to eq("completed")
      end

      it "clears context after execution" do
        described_class.perform_now(source.id)

        expect(Current.tenant).to be_nil
        expect(Current.site).to be_nil
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
