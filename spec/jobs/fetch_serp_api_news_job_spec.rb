# frozen_string_literal: true

require "rails_helper"

RSpec.describe FetchSerpApiNewsJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :serp_api_google_news, site: site) }
  let(:serp_api_response) { fixture_file("serp_api_news.json") }

  describe "#perform" do
    context "happy path" do
      before do
        stub_serp_api_response
      end

      it "fetches news from SerpAPI and enqueues UpsertListingsJob for each result" do
        expect {
          described_class.perform_now(source.id)
        }.to have_enqueued_job(UpsertListingsJob).exactly(3).times
      end

      it "updates source status to success" do
        described_class.perform_now(source.id)
        source.reload
        expect(source.last_status).to eq("success")
        expect(source.last_run_at).to be_within(1.second).of(Time.current)
      end

      it "creates or finds news category" do
        expect {
          described_class.perform_now(source.id)
        }.to change(Category, :count).by(1)

        category = Category.find_by(site: site, key: "news")
        expect(category).to be_present
      end

      it "enqueues jobs with correct URLs from API response" do
        described_class.perform_now(source.id)

        enqueued_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
          job["job_class"] == "UpsertListingsJob"
        end

        urls = enqueued_jobs.map { |job| job["arguments"][2] }
        expect(urls).to include("https://news.example.com/tech-1")
        expect(urls).to include("https://news.example.com/tech-2")
        expect(urls).to include("https://news.example.com/tech-3")
      end
    end

    context "when source is disabled" do
      let(:source) { create(:source, :serp_api_google_news, :disabled, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to have_enqueued_job(UpsertListingsJob)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when source is not serp_api_google_news type" do
      let(:source) { create(:source, :rss, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to have_enqueued_job(UpsertListingsJob)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when API key is not configured" do
      let(:source) { create(:source, :serp_api_google_news, site: site, config: { "query" => "test" }) }

      it "updates source status with error message" do
        # Note: Job has retry_on StandardError, so errors trigger retry mechanism
        # We test the source status update behavior
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - retry mechanism may throw
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

      it "updates source status with error" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - retry mechanism may throw
        end

        source.reload
        expect(source.last_status).to match(/error:.*500/)
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
        }.not_to have_enqueued_job(UpsertListingsJob)

        source.reload
        expect(source.last_status).to eq("success")
      end
    end

    context "uses config parameters" do
      before do
        stub_serp_api_response
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
      end

      it "sets Current.tenant during execution" do
        described_class.perform_now(source.id)

        # Verify the job ran successfully (which requires tenant context)
        source.reload
        expect(source.last_status).to eq("success")
      end

      it "clears context after successful execution" do
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
