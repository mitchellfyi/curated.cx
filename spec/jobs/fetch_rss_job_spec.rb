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

      it "fetches RSS feed and enqueues UpsertEntriesJob for each entry" do
        expect {
          described_class.perform_now(source.id)
        }.to have_enqueued_job(UpsertEntriesJob).exactly(3).times
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
          job["job_class"] == "UpsertEntriesJob"
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
        }.not_to have_enqueued_job(UpsertEntriesJob)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when source is not RSS type" do
      let(:source) { create(:source, :serp_api_google_news, site: site) }

      it "skips processing and updates status to skipped" do
        expect {
          described_class.perform_now(source.id)
        }.not_to have_enqueued_job(UpsertEntriesJob)

        source.reload
        expect(source.last_status).to eq("skipped")
      end
    end

    context "when feed URL is not configured" do
      let(:source) { create(:source, :rss, site: site, config: {}) }

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

    context "when HTTP request fails" do
      before do
        stub_request(:get, "https://example.com/feed.xml")
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

    context "when RSS XML is invalid" do
      before do
        stub_rss_feed("https://example.com/feed.xml", body: "not valid xml at all")
      end

      it "updates source status with parse error" do
        begin
          described_class.perform_now(source.id)
        rescue StandardError
          # Expected - retry mechanism may throw
        end

        source.reload
        expect(source.last_status).to start_with("error:")
      end
    end

    context "tenant context management" do
      before do
        stub_rss_feed("https://example.com/feed.xml", body: rss_feed_content)
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
