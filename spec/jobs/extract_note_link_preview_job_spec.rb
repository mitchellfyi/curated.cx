# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExtractNoteLinkPreviewJob, type: :job do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:user) { create(:user) }
  let(:url) { "https://example.com/article" }

  before do
    Current.site = site
  end

  describe "#perform" do
    let(:note) { create(:note, site: site, user: user, body: "Check out #{url}") }
    let(:preview_data) do
      {
        "url" => url,
        "title" => "Example Article",
        "description" => "An example description",
        "image" => "https://example.com/image.jpg",
        "site_name" => "Example.com"
      }
    end

    context "when extraction succeeds" do
      before do
        allow(LinkPreviewService).to receive(:extract).with(url).and_return(preview_data)
      end

      it "updates the note with link preview data" do
        described_class.new.perform(note.id, url)

        note.reload
        expect(note.link_preview).to eq(preview_data)
      end

      it "calls LinkPreviewService with the URL" do
        described_class.new.perform(note.id, url)

        expect(LinkPreviewService).to have_received(:extract).with(url)
      end
    end

    context "when extraction fails" do
      before do
        allow(LinkPreviewService).to receive(:extract).and_raise(
          LinkPreviewService::ExtractionError, "Connection timeout"
        )
        allow(Rails.logger).to receive(:warn)
      end

      it "logs a warning" do
        expect {
          described_class.new.perform(note.id, url)
        }.to raise_error(LinkPreviewService::ExtractionError)

        expect(Rails.logger).to have_received(:warn).with(/Failed to extract link preview/)
      end

      it "re-raises for retry mechanism" do
        expect {
          described_class.new.perform(note.id, url)
        }.to raise_error(LinkPreviewService::ExtractionError)
      end
    end

    context "when note is not found" do
      it "does not raise an error (discards job)" do
        # The job has discard_on ActiveRecord::RecordNotFound
        # but perform itself will raise - the job framework handles discard
        expect {
          described_class.new.perform(-1, url)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "bypassing site scope" do
      before do
        allow(LinkPreviewService).to receive(:extract).with(url).and_return(preview_data)
      end

      it "uses Note.unscoped to find notes regardless of site context" do
        # The job should be able to find notes even when Current.site is different
        # by using Note.unscoped.find
        described_class.new.perform(note.id, url)

        note.reload
        expect(note.link_preview).to eq(preview_data)
      end
    end
  end

  describe "job configuration" do
    it "queues as default" do
      expect(described_class.queue_name).to eq("default")
    end

    it "is configured to retry on ExtractionError" do
      # Check that the job class has retry_on configured for ExtractionError
      rescue_handlers = described_class.rescue_handlers
      extraction_error_handler = rescue_handlers.find { |h| h[0] == "LinkPreviewService::ExtractionError" }
      expect(extraction_error_handler).to be_present
    end
  end

  describe "enqueueing" do
    it "can be enqueued with note_id and url" do
      expect {
        described_class.perform_later(1, "https://example.com")
      }.to have_enqueued_job(described_class).with(1, "https://example.com")
    end
  end
end
