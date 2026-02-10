# frozen_string_literal: true

require "rails_helper"

RSpec.describe CaptureScreenshotJob, type: :job do
  include ActiveJob::TestHelper

  let(:entry) { create(:entry, :feed) }

  describe "queue configuration" do
    it "uses the screenshots queue" do
      expect(described_class.new.queue_name).to eq("screenshots")
    end
  end

  describe "retry configuration" do
    it "retries on ScreenshotError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "ScreenshotService::ScreenshotError" }
      expect(handler).to be_present
    end

    it "discards on ConfigurationError" do
      handler = described_class.rescue_handlers.find { |h| h[0] == "ScreenshotService::ConfigurationError" }
      expect(handler).to be_present
    end
  end

  describe "#perform" do
    context "when screenshot already exists" do
      let(:entry) { create(:entry, :feed, :with_screenshot) }

      it "does not call ScreenshotService" do
        expect(ScreenshotService).not_to receive(:capture_for_entry)

        described_class.new.perform(entry.id)
      end
    end

    context "when screenshot does not exist" do
      let(:result) { { screenshot_url: "https://screenshots.example.com/new.png", captured_at: Time.current } }

      it "calls ScreenshotService.capture_for_entry" do
        expect(ScreenshotService).to receive(:capture_for_entry).with(entry).and_return(result)

        described_class.new.perform(entry.id)
      end
    end

    context "when entry is not found" do
      it "discards the job (ActiveRecord::RecordNotFound)" do
        expect { described_class.perform_now(0) }.not_to raise_error
      end
    end
  end
end
