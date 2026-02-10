# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefreshScreenshotsJob, type: :job do
  include ActiveJob::TestHelper

  describe "queue configuration" do
    it "uses the screenshots queue" do
      expect(described_class.new.queue_name).to eq("screenshots")
    end
  end

  describe "constants" do
    it "has expected default values" do
      expect(RefreshScreenshotsJob::REFRESH_INTERVAL).to eq(7.days)
      expect(RefreshScreenshotsJob::BATCH_SIZE).to eq(50)
    end
  end

  describe "#perform" do
    context "with stale screenshots" do
      let!(:stale_item) { create(:entry, :feed, :with_stale_screenshot) }
      let!(:fresh_item) { create(:entry, :feed, :with_screenshot) }

      it "enqueues CaptureScreenshotJob for stale items" do
        expect {
          described_class.perform_now
        }.to have_enqueued_job(CaptureScreenshotJob).with(stale_item.id)
      end

      it "does not enqueue CaptureScreenshotJob for fresh items" do
        described_class.perform_now

        expect(CaptureScreenshotJob).not_to have_been_enqueued.with(fresh_item.id)
      end

      it "clears the screenshot data for stale items" do
        described_class.perform_now

        stale_item.reload
        expect(stale_item.screenshot_url).to be_nil
        expect(stale_item.screenshot_captured_at).to be_nil
      end
    end

    context "with no stale screenshots" do
      let!(:fresh_item) { create(:entry, :feed, :with_screenshot) }

      it "does not enqueue any jobs" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_job(CaptureScreenshotJob)
      end
    end

    context "with items that have no screenshots" do
      let!(:item_without_screenshot) { create(:entry, :feed) }

      it "does not enqueue any jobs" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_job(CaptureScreenshotJob)
      end
    end
  end
end
