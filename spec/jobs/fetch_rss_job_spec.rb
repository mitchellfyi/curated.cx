# frozen_string_literal: true

require "rails_helper"

RSpec.describe FetchRssJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :rss, site: site, config: { "url" => "https://example.com/feed.xml" }) }
  let(:rss_feed_content) { fixture_file("sample_feed.xml") }

  describe "#perform" do
    context "happy path" do
      before do
        stub_rss_feed("https://example.com/feed.xml", body: rss_feed_content)
      end

      it "fetches RSS feed and enqueues UpsertListingsJob for each entry" do
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
        expect(category.name).to eq("News")
      end

      it "enqueues jobs with correct URLs from feed" do
        described_class.perform_now(source.id)

        enqueued_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
          job["job_class"] == "UpsertListingsJob"
        end

        urls = enqueued_jobs.map { |job| job["arguments"][2] }
        expect(urls).to include("https://example.com/article-1")
        expect(urls).to include("https://example.com/article-2")
        expect(urls).to include("https://example.com/article-3")
      end
    end

    context "when source is disabled" do
      let(:source) { create(:source, :rss, :disabled, site: site, config: { "url" => "https://example.com/feed.xml" }) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to have_enqueued_job(UpsertListingsJob)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when source is not RSS type" do
      let(:source) { create(:source, :serp_api_google_news, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to have_enqueued_job(UpsertListingsJob)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when feed URL is not configured" do
      let(:source) { create(:source, :rss, site: site, config: {}) }

      it "raises error about missing URL" do
        expect {
          described_class.perform_now(source.id)
        }.to raise_error("RSS feed URL not configured")
      end

      it "updates source status with error message" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected
        end

        source.reload
        expect(source.last_status).to start_with("error:")
      end
    end

    context "when HTTP request fails" do
      before do
        stub_request(:get, "https://example.com/feed.xml")
          .to_return(status: 500, body: "Internal Server Error")
      end

      it "raises error for HTTP failure" do
        expect {
          described_class.perform_now(source.id)
        }.to raise_error(/Feed fetch failed: 500/)
      end

      it "updates source status with error" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected
        end

        source.reload
        expect(source.last_status).to match(/error:.*500/)
      end
    end

    context "when RSS XML is invalid" do
      before do
        stub_rss_feed("https://example.com/feed.xml", body: "not valid xml at all")
      end

      it "raises error for invalid XML" do
        expect {
          described_class.perform_now(source.id)
        }.to raise_error(Feedjira::NoParserAvailable)
      end
    end

    context "tenant context management" do
      before do
        stub_rss_feed("https://example.com/feed.xml", body: rss_feed_content)
      end

      it "sets Current.tenant during execution" do
        expect(Current).to receive(:tenant=).with(tenant).ordered
        expect(Current).to receive(:site=).with(site).ordered
        expect(Current).to receive(:tenant=).with(nil).ordered
        expect(Current).to receive(:site=).with(nil).ordered

        described_class.perform_now(source.id)
      end

      it "clears context even when error occurs" do
        stub_request(:get, "https://example.com/feed.xml")
          .to_return(status: 500, body: "Error")

        expect(Current).to receive(:tenant=).with(nil).at_least(:once)
        expect(Current).to receive(:site=).with(nil).at_least(:once)

        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected
        end
      end
    end

    context "existing category" do
      let!(:existing_category) { create(:category, site: site, tenant: tenant, key: "news", name: "News") }

      before do
        stub_rss_feed("https://example.com/feed.xml", body: rss_feed_content)
      end

      it "uses existing category instead of creating new one" do
        expect {
          described_class.perform_now(source.id)
        }.not_to change(Category, :count)
      end
    end
  end

  describe "retry behavior" do
    it "is configured to retry on StandardError" do
      expect(described_class.rescue_handlers).to include(
        a_hash_including("error_class" => "StandardError")
      )
    end

    it "uses exponential backoff" do
      handler = described_class.rescue_handlers.find { |h| h["error_class"] == "StandardError" }
      expect(handler["wait"]).to eq(:exponentially_longer)
    end

    it "retries up to 3 times" do
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
