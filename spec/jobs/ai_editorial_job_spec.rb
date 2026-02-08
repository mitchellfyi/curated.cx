# frozen_string_literal: true

require "rails_helper"

RSpec.describe AiEditorialJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site, config: { "editorialise" => true }) }
  let(:content_item) do
    create(:content_item,
      site: site,
      source: source,
      extracted_text: "A" * 500
    )
  end

  let(:ai_response) do
    {
      content: {
        "summary" => "Test summary",
        "why_it_matters" => "Test context",
        "suggested_tags" => ["tag1"]
      }.to_json,
      tokens_used: 100,
      model: "gpt-4o-mini",
      duration_ms: 1000
    }
  end

  before do
    allow_any_instance_of(ContentItem).to receive(:enqueue_enrichment_pipeline)
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:validate_api_key!)
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete).and_return(ai_response)
  end

  describe "queue configuration" do
    it "uses the editorialisation queue" do
      expect(described_class.new.queue_name).to eq("editorialisation")
    end
  end

  describe "retry configuration" do
    it "retries on AiApiError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiApiError" }
      expect(handler).to be_present
    end

    it "retries on AiTimeoutError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiTimeoutError" }
      expect(handler).to be_present
    end

    it "retries on AiRateLimitError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiRateLimitError" }
      expect(handler).to be_present
    end
  end

  describe "discard configuration" do
    it "discards on AiInvalidResponseError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiInvalidResponseError" }
      expect(handler).to be_present
    end

    it "discards on AiConfigurationError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiConfigurationError" }
      expect(handler).to be_present
    end
  end

  describe "#perform" do
    it "calls EditorialisationService with the content item" do
      expect(EditorialisationService).to receive(:editorialise).with(content_item).and_call_original

      described_class.perform_now(content_item.id)
    end

    it "enqueues CaptureScreenshotJob after completion" do
      expect {
        described_class.perform_now(content_item.id)
      }.to have_enqueued_job(CaptureScreenshotJob).with(content_item.id)
    end

    it "marks enrichment as complete" do
      described_class.perform_now(content_item.id)

      expect(content_item.reload.enrichment_status).to eq("complete")
      expect(content_item.reload.enriched_at).to be_present
    end

    it "clears Current context after execution" do
      described_class.perform_now(content_item.id)

      expect(Current.tenant).to be_nil
      expect(Current.site).to be_nil
    end

    context "when AI usage limit is reached" do
      before do
        allow(AiUsageTracker).to receive(:can_make_request?).and_return(false)
      end

      it "skips AI processing" do
        expect(EditorialisationService).not_to receive(:editorialise)

        described_class.perform_now(content_item.id)
      end

      it "still enqueues screenshot job" do
        expect {
          described_class.perform_now(content_item.id)
        }.to have_enqueued_job(CaptureScreenshotJob).with(content_item.id)
      end

      it "marks enrichment as complete" do
        described_class.perform_now(content_item.id)

        expect(content_item.reload.enrichment_status).to eq("complete")
      end
    end

    context "when content item is not found" do
      it "discards the job" do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end
  end
end
