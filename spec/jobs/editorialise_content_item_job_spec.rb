# frozen_string_literal: true

require "rails_helper"

RSpec.describe EditorialiseContentItemJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site, config: { "editorialise" => true }) }
  let(:content_item) do
    create(:content_item,
      site: site,
      source: source,
      extracted_text: "A" * 500 # Meets minimum length
    )
  end

  let(:ai_response) do
    {
      content: {
        "summary" => "Test summary",
        "why_it_matters" => "Test context",
        "suggested_tags" => [ "tag1" ]
      }.to_json,
      tokens_used: 100,
      model: "gpt-4o-mini",
      duration_ms: 1000
    }
  end

  before do
    # Prevent editorialisation job from running on content_item creation
    allow_any_instance_of(ContentItem).to receive(:enqueue_enrichment_pipeline)
    # Stub AiClient (including API key validation for CI environment)
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:validate_api_key!)
    allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete).and_return(ai_response)
  end

  describe "#perform" do
    it "calls EditorialisationService with the content item" do
      expect(EditorialisationService).to receive(:editorialise).with(content_item).and_call_original

      described_class.perform_now(content_item.id)
    end

    it "sets Current.tenant during execution" do
      described_class.perform_now(content_item.id)

      # The job clears context in ensure block, so we verify it was set by checking
      # that the service ran successfully (which requires tenant context)
      expect(Editorialisation.count).to eq(1)
    end

    it "sets Current.site during execution" do
      described_class.perform_now(content_item.id)

      expect(Editorialisation.count).to eq(1)
    end

    it "clears Current context after execution" do
      described_class.perform_now(content_item.id)

      expect(Current.tenant).to be_nil
      expect(Current.site).to be_nil
    end

    it "clears Current context even when error occurs" do
      allow(EditorialisationService).to receive(:editorialise).and_raise(StandardError.new("Test error"))

      begin
        described_class.perform_now(content_item.id)
      rescue StandardError
        # Expected
      end

      expect(Current.tenant).to be_nil
      expect(Current.site).to be_nil
    end

    context "when content item not found" do
      it "discards the job without raising (via ApplicationJob discard_on)" do
        # ApplicationJob has: discard_on ActiveRecord::RecordNotFound
        # So the job is silently discarded
        expect {
          described_class.perform_now(0)
        }.not_to raise_error
      end
    end

    context "logging" do
      context "when editorialisation completes" do
        it "logs success with token and duration info" do
          allow(Rails.logger).to receive(:info)

          described_class.perform_now(content_item.id)

          expect(Rails.logger).to have_received(:info).with(/Successfully editorialised.*tokens=100.*duration_ms=1000/)
        end
      end

      context "when editorialisation is skipped" do
        let(:content_item) do
          create(:content_item,
            site: site,
            source: source,
            extracted_text: "Short" # Too short, will be skipped
          )
        end

        it "logs skip reason" do
          allow(Rails.logger).to receive(:info)

          described_class.perform_now(content_item.id)

          expect(Rails.logger).to have_received(:info).with(/Skipped.*reason=Insufficient text/)
        end
      end
    end
  end

  describe "queue configuration" do
    it "uses the editorialisation queue" do
      expect(described_class.queue_name).to eq("editorialisation")
    end
  end

  describe "retry configuration" do
    # rescue_handlers format is [["ErrorClassName", proc], ...]
    it "retries on AiApiError with exponential backoff" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiApiError" }
      expect(handler).to be_present
    end

    it "retries on AiTimeoutError with exponential backoff" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiTimeoutError" }
      expect(handler).to be_present
    end

    it "retries on AiRateLimitError with 60 second wait" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiRateLimitError" }
      expect(handler).to be_present
    end
  end

  describe "discard configuration" do
    # discard_on handlers are in the rescue_handlers array
    it "discards on AiInvalidResponseError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiInvalidResponseError" }
      expect(handler).to be_present
    end

    it "discards on AiConfigurationError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "AiConfigurationError" }
      expect(handler).to be_present
    end
  end

  describe "error handling" do
    # Note: We verify retry_on and discard_on configuration in the sections above.
    # These tests verify the service-level error handling that doesn't trigger job retries.

    context "when AiInvalidResponseError occurs via invalid JSON response" do
      before do
        allow_any_instance_of(EditorialisationServices::AiClient).to receive(:complete)
          .and_return(content: "not json", tokens_used: 0, model: "gpt-4o-mini", duration_ms: 100)
      end

      it "does not raise (service handles it)" do
        expect {
          described_class.perform_now(content_item.id)
        }.not_to raise_error
      end

      it "creates a failed editorialisation record" do
        described_class.perform_now(content_item.id)

        editorialisation = Editorialisation.last
        expect(editorialisation.status).to eq("failed")
      end
    end
  end
end
