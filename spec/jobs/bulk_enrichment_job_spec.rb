# frozen_string_literal: true

require "rails_helper"

RSpec.describe BulkEnrichmentJob, type: :job do
  include ActiveJob::TestHelper

  before do
    allow_any_instance_of(ContentItem).to receive(:enqueue_enrichment_pipeline)
  end

  describe "queue configuration" do
    it "uses the low queue" do
      expect(described_class.new.queue_name).to eq("low")
    end
  end

  describe "#perform" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    context "with specific content_item_ids" do
      let!(:item1) { create(:content_item, site: site, source: source) }
      let!(:item2) { create(:content_item, site: site, source: source) }

      it "enqueues EnrichContentItemJob for each specified item" do
        expect {
          described_class.perform_now(content_item_ids: [item1.id, item2.id])
        }.to have_enqueued_job(EnrichContentItemJob).exactly(2).times
      end

      it "resets enrichment status" do
        item1.update_columns(enrichment_status: "complete", enriched_at: Time.current)

        described_class.perform_now(content_item_ids: [item1.id])

        expect(item1.reload.enrichment_status).to eq("pending")
      end
    end

    context "with scope: pending" do
      let!(:pending_item) { create(:content_item, site: site, source: source) }
      let!(:complete_item) { create(:content_item, :enrichment_complete, site: site, source: source) }

      it "only enqueues for pending items" do
        expect {
          described_class.perform_now(scope: "pending")
        }.to have_enqueued_job(EnrichContentItemJob).with(pending_item.id)
      end

      it "does not enqueue for complete items" do
        described_class.perform_now(scope: "pending")

        expect(EnrichContentItemJob).not_to have_been_enqueued.with(complete_item.id)
      end
    end

    context "with scope: failed" do
      let!(:failed_item) { create(:content_item, :enrichment_failed, site: site, source: source) }
      let!(:pending_item) { create(:content_item, site: site, source: source) }

      it "only enqueues for failed items" do
        expect {
          described_class.perform_now(scope: "failed")
        }.to have_enqueued_job(EnrichContentItemJob).with(failed_item.id)
      end
    end

    context "with scope: all" do
      let!(:pending_item) { create(:content_item, site: site, source: source) }
      let!(:complete_item) { create(:content_item, :enrichment_complete, site: site, source: source) }

      it "enqueues for all non-enriching items" do
        expect {
          described_class.perform_now(scope: "all")
        }.to have_enqueued_job(EnrichContentItemJob).at_least(2).times
      end
    end
  end
end
