# frozen_string_literal: true

require "rails_helper"

RSpec.describe RefreshMetadataJob, type: :job do
  include ActiveJob::TestHelper

  before do
    allow_any_instance_of(Entry).to receive(:enqueue_enrichment_pipeline)
  end

  describe "queue configuration" do
    it "uses the low queue" do
      expect(described_class.new.queue_name).to eq("low")
    end
  end

  describe "#perform" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    context "with stale enriched items" do
      let!(:stale_item) { create(:entry, :feed, :enrichment_stale, site: site, source: source) }
      let!(:fresh_item) { create(:entry, :feed, :enrichment_complete, site: site, source: source) }

      it "enqueues EnrichEntryJob for stale items" do
        expect {
          described_class.perform_now
        }.to have_enqueued_job(EnrichEntryJob).with(stale_item.id)
      end

      it "does not enqueue for fresh items" do
        described_class.perform_now

        expect(EnrichEntryJob).not_to have_been_enqueued.with(fresh_item.id)
      end

      it "resets enrichment status for stale items" do
        described_class.perform_now

        expect(stale_item.reload.enrichment_status).to eq("pending")
      end
    end

    context "with no stale items" do
      it "does not enqueue any jobs" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_job(EnrichEntryJob)
      end
    end

    context "with custom stale interval" do
      let!(:item) { create(:entry, :feed, :enrichment_complete, site: site, source: source) }

      before do
        # Make enriched_at 8 days ago
        item.update_columns(enriched_at: 8.days.ago)
      end

      it "uses the custom interval" do
        expect {
          described_class.perform_now(stale_interval: 7.days)
        }.to have_enqueued_job(EnrichEntryJob).with(item.id)
      end
    end
  end
end
