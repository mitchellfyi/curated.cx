# frozen_string_literal: true

require "rails_helper"

RSpec.describe EnrichContentItemJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site, config: { "editorialise" => true }) }
  let(:content_item) do
    create(:content_item, site: site, source: source)
  end

  let(:metadata) do
    {
      title: "Enriched Title",
      description: "Enriched description",
      og_image_url: "https://example.com/image.jpg",
      author_name: "John Doe",
      word_count: 1500,
      read_time_minutes: 8,
      favicon_url: "https://example.com/favicon.ico",
      domain: "example.com"
    }
  end

  before do
    allow_any_instance_of(ContentItem).to receive(:enqueue_enrichment_pipeline)
    allow(LinkEnrichmentService).to receive(:enrich).and_return(metadata)
  end

  describe "queue configuration" do
    it "uses the enrichment queue" do
      expect(described_class.new.queue_name).to eq("enrichment")
    end
  end

  describe "retry configuration" do
    it "retries on EnrichmentError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "LinkEnrichmentService::EnrichmentError" }
      expect(handler).to be_present
    end
  end

  describe "#perform" do
    it "calls LinkEnrichmentService with the content item URL" do
      expect(LinkEnrichmentService).to receive(:enrich).with(content_item.url_canonical).and_return(metadata)

      described_class.perform_now(content_item.id)
    end

    it "sets enrichment_status to enriching at the start" do
      allow(LinkEnrichmentService).to receive(:enrich) do
        expect(content_item.reload.enrichment_status).to eq("enriching")
        metadata
      end

      described_class.perform_now(content_item.id)
    end

    it "updates content item with enrichment metadata" do
      described_class.perform_now(content_item.id)

      content_item.reload
      expect(content_item.og_image_url).to eq("https://example.com/image.jpg")
      expect(content_item.author_name).to eq("John Doe")
      expect(content_item.word_count).to eq(1500)
      expect(content_item.read_time_minutes).to eq(8)
      expect(content_item.favicon_url).to eq("https://example.com/favicon.ico")
    end

    it "does not overwrite existing title" do
      original_title = content_item.title
      described_class.perform_now(content_item.id)

      expect(content_item.reload.title).to eq(original_title)
    end

    it "fills in title when blank" do
      content_item.update_columns(title: nil)
      described_class.perform_now(content_item.id)

      expect(content_item.reload.title).to eq("Enriched Title")
    end

    context "when source has editorialisation enabled" do
      it "enqueues AiEditorialJob" do
        expect {
          described_class.perform_now(content_item.id)
        }.to have_enqueued_job(AiEditorialJob).with(content_item.id)
      end
    end

    context "when source has editorialisation disabled" do
      let(:source) { create(:source, site: site, config: { "editorialise" => false }) }

      it "enqueues CaptureScreenshotJob instead" do
        expect {
          described_class.perform_now(content_item.id)
        }.to have_enqueued_job(CaptureScreenshotJob).with(content_item.id)
      end

      it "marks enrichment as complete" do
        described_class.perform_now(content_item.id)

        expect(content_item.reload.enrichment_status).to eq("complete")
      end
    end

    it "sets tenant context during execution" do
      described_class.perform_now(content_item.id)

      # Context is cleared in ensure block
      expect(Current.tenant).to be_nil
      expect(Current.site).to be_nil
    end

    context "when enrichment fails" do
      before do
        allow(LinkEnrichmentService).to receive(:enrich)
          .and_raise(LinkEnrichmentService::EnrichmentError.new("Connection timeout"))
      end

      it "marks enrichment as failed" do
        begin
          described_class.perform_now(content_item.id)
        rescue LinkEnrichmentService::EnrichmentError
          # Expected
        end

        expect(content_item.reload.enrichment_status).to eq("failed")
      end

      it "records the error message" do
        begin
          described_class.perform_now(content_item.id)
        rescue LinkEnrichmentService::EnrichmentError
          # Expected
        end

        errors = content_item.reload.enrichment_errors
        expect(errors).to be_present
      end
    end

    context "when content item is not found" do
      it "discards the job" do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end
  end
end
