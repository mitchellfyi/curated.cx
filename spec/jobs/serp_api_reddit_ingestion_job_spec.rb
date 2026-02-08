# frozen_string_literal: true

require "rails_helper"

RSpec.describe SerpApiRedditIngestionJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :reddit_search, site: site) }

  describe "#perform" do
    context "happy path" do
      before do
        stub_reddit_search_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "creates ContentItems from Reddit results" do
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

      it "stores correct ContentItem attributes for self-posts" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Best practices for building a SaaS startup?")
        expect(item).to be_present
        expect(item.url_raw).to include("reddit.com/r/startups")
        expect(item.description).to include("SaaS product")
        expect(item.author_name).to eq("startup_founder")
        expect(item.og_image_url).to eq("https://preview.redd.it/abc123.jpg")
        expect(item.source).to eq(source)
        expect(item.site).to eq(site)
      end

      it "stores subreddit in raw_payload" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Best practices for building a SaaS startup?")
        expect(item.raw_payload.dig("_reddit_metadata", "subreddit")).to eq("r/startups")
      end

      it "stores upvotes in raw_payload" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Best practices for building a SaaS startup?")
        expect(item.raw_payload.dig("_reddit_metadata", "upvotes")).to eq(342)
      end

      it "stores comment count in raw_payload" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Best practices for building a SaaS startup?")
        expect(item.raw_payload.dig("_reddit_metadata", "comment_count")).to eq(87)
      end

      it "stores author in raw_payload" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Best practices for building a SaaS startup?")
        expect(item.raw_payload.dig("_reddit_metadata", "author")).to eq("startup_founder")
      end

      it "tags self-posts correctly" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Best practices for building a SaaS startup?")
        expect(item.tags).to include("source:reddit")
        expect(item.tags).to include("subreddit:startups")
        expect(item.tags).to include("reddit:self_post")
      end

      it "tags link posts correctly" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "Comparison of no-code tools for MVPs")
        expect(item.tags).to include("source:reddit")
        expect(item.tags).to include("subreddit:nocode")
        expect(item.tags).to include("reddit:link_post")
      end

      it "handles posts without thumbnails" do
        described_class.perform_now(source.id)

        item = ContentItem.find_by(title: "How I grew my newsletter to 10k subscribers")
        expect(item.og_image_url).to be_nil
      end

      it "marks self-posts in raw_payload" do
        described_class.perform_now(source.id)

        self_post = ContentItem.find_by(title: "Best practices for building a SaaS startup?")
        expect(self_post.raw_payload.dig("_reddit_metadata", "is_self_post")).to be true

        link_post = ContentItem.find_by(title: "Comparison of no-code tools for MVPs")
        expect(link_post.raw_payload.dig("_reddit_metadata", "is_self_post")).to be false
      end
    end

    context "subreddit filtering" do
      let(:source) do
        create(:source, :reddit_search, site: site, config: {
          "api_key" => "test_api_key",
          "query" => "startup advice",
          "subreddit" => "startups"
        })
      end

      before do
        stub_reddit_search_response
        allow(TaggingService).to receive(:tag).and_return({
          topic_tags: [],
          content_type: "article",
          confidence: 0.9,
          explanation: []
        })
      end

      it "sends subreddit parameter to SerpAPI" do
        described_class.perform_now(source.id)

        expect(WebMock).to have_requested(:get, /serpapi\.com\/search\.json/)
          .with(query: hash_including(
            "engine" => "reddit_search",
            "subreddit" => "startups"
          ))
      end
    end

    context "deduplication" do
      before do
        stub_reddit_search_response
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
        create(:source, :reddit_search, site: site, config: {
          "api_key" => "test_api_key",
          "query" => "startup advice",
          "max_results" => 2
        })
      end

      before do
        stub_reddit_search_response
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
      let(:source) { create(:source, :reddit_search, :disabled, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(ContentItem, :count)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when source is not reddit_search type" do
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
        create(:source, :reddit_search, site: site, config: { "query" => "test" })
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
        create(:source, :reddit_search, site: site, config: { "api_key" => "test_key" })
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
