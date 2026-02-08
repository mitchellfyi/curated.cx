# frozen_string_literal: true

require "rails_helper"

RSpec.describe SerpApiGoogleScholarIngestionJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :google_scholar, site: site) }

  describe "#perform" do
    context "happy path" do
      before do
        stub_google_scholar_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "creates ContentItems from Google Scholar results" do
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

        item = ContentItem.find_by(title: "Attention Is All You Need")
        expect(item).to be_present
        expect(item.url_raw).to eq("https://arxiv.org/abs/1706.03762")
        expect(item.description).to include("dominant sequence transduction")
        expect(item.source).to eq(source)
        expect(item.site).to eq(site)
      end

      it "stores citation count in raw_payload" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Attention Is All You Need")
        expect(item.raw_payload.dig("_scholar_metadata", "citations")).to eq(95000)
      end

      it "stores PDF URL in raw_payload when available" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Attention Is All You Need")
        expect(item.raw_payload.dig("_scholar_metadata", "pdf_url")).to eq("https://arxiv.org/pdf/1706.03762")
      end

      it "stores publication info in raw_payload" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Attention Is All You Need")
        expect(item.raw_payload.dig("_scholar_metadata", "publication")).to include("Advances in neural information processing systems")
      end

      it "handles papers without PDF links" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "BERT: Pre-training of Deep Bidirectional Transformers")
        expect(item.raw_payload.dig("_scholar_metadata", "pdf_url")).to be_nil
      end

      it "extracts academic paper tags" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Attention Is All You Need")
        expect(item.tags).to include("content_type:academic_paper")
        expect(item.tags).to include("year:2017")
      end
    end

    context "year filtering" do
      let(:source) do
        create(:source, :google_scholar, site: site, config: {
          "api_key" => "test_api_key",
          "query" => "machine learning",
          "year_from" => "2020"
        })
      end

      before do
        stub_google_scholar_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "sends year_from parameter to SerpAPI" do
        described_class.perform_now(source.id)

        expect(WebMock).to have_requested(:get, /serpapi\.com\/search\.json/)
          .with(query: hash_including(
            "engine" => "google_scholar",
            "as_ylo" => "2020"
          ))
      end
    end

    context "deduplication" do
      before do
        stub_google_scholar_response
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
    end

    context "max_results configuration" do
      let(:source) do
        create(:source, :google_scholar, site: site, config: {
          "api_key" => "test_api_key",
          "query" => "machine learning",
          "max_results" => 2
        })
      end

      before do
        stub_google_scholar_response
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
      let(:source) { create(:source, :google_scholar, :disabled, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ContentItem, :count)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when source is not google_scholar type" do
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
        create(:source, :google_scholar, site: site, config: { "query" => "test" })
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
        create(:source, :google_scholar, site: site, config: { "api_key" => "test_key" })
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

    context "when organic_results is empty" do
      before do
        stub_request(:get, /serpapi\.com\/search\.json/)
          .to_return(
            status: 200,
            body: { "organic_results" => [] }.to_json,
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
    end
  end

  describe "queue configuration" do
    it "uses the ingestion queue" do
      expect(described_class.queue_name).to eq("ingestion")
    end
  end
end
