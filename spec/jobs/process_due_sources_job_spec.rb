# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProcessDueSourcesJob, type: :job do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }

  describe "#perform" do
    context "with sources due for run" do
      let!(:due_serp_source) do
        create(:source, :serp_api_google_news, :due_for_run, site: site)
      end

      let!(:due_rss_source) do
        create(:source, :rss, :due_for_run, site: site)
      end

      it "enqueues SerpApiIngestionJob for serp_api_google_news sources" do
        expect {
          described_class.perform_now
        }.to have_enqueued_job(SerpApiIngestionJob).with(due_serp_source.id)
      end

      it "does not enqueue jobs for unmapped source kinds" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_job(SerpApiIngestionJob).with(due_rss_source.id)
      end

      it "logs info for unmapped source kinds" do
        allow(Rails.logger).to receive(:info)
        described_class.perform_now
        expect(Rails.logger).to have_received(:info).with(/No job mapping for source kind 'rss'/)
      end
    end

    context "with no sources due for run" do
      let!(:recently_run_source) do
        create(:source, :serp_api_google_news, :recently_run, site: site)
      end

      it "does not enqueue any jobs" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_job(SerpApiIngestionJob)
      end
    end

    context "with disabled sources" do
      let!(:disabled_due_source) do
        create(:source, :serp_api_google_news, :due_for_run, :disabled, site: site)
      end

      it "does not enqueue jobs for disabled sources" do
        expect {
          described_class.perform_now
        }.not_to have_enqueued_job(SerpApiIngestionJob)
      end
    end

    context "with multiple enabled sources due for run" do
      let!(:source1) do
        create(:source, :serp_api_google_news, :due_for_run, site: site, name: "Source 1")
      end
      let!(:source2) do
        create(:source, :serp_api_google_news, :due_for_run, site: site, name: "Source 2")
      end
      let!(:source3) do
        create(:source, :serp_api_google_news, :due_for_run, site: site, name: "Source 3")
      end

      it "enqueues jobs for all due sources" do
        described_class.perform_now

        expect(SerpApiIngestionJob).to have_been_enqueued.with(source1.id)
        expect(SerpApiIngestionJob).to have_been_enqueued.with(source2.id)
        expect(SerpApiIngestionJob).to have_been_enqueued.with(source3.id)
      end
    end

    context "with sources that have never been run" do
      let!(:new_source) do
        create(:source, :serp_api_google_news, site: site, last_run_at: nil)
      end

      it "enqueues jobs for sources that have never been run" do
        expect {
          described_class.perform_now
        }.to have_enqueued_job(SerpApiIngestionJob).with(new_source.id)
      end
    end

    context "when job enqueue fails" do
      let!(:due_source) do
        create(:source, :serp_api_google_news, :due_for_run, site: site)
      end

      before do
        allow(SerpApiIngestionJob).to receive(:perform_later).and_raise(StandardError, "Queue error")
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(
          /Failed to enqueue job for source #{due_source.id}: Queue error/
        )
        described_class.perform_now
      end

      it "does not raise the error (continues processing)" do
        expect {
          described_class.perform_now
        }.not_to raise_error
      end
    end

    context "with sources from multiple tenants" do
      let(:tenant2) { create(:tenant) }
      let(:site2) { create(:site, tenant: tenant2) }
      let!(:source_tenant1) do
        create(:source, :serp_api_google_news, :due_for_run, site: site, name: "Tenant 1 Source")
      end
      let!(:source_tenant2) do
        create(:source, :serp_api_google_news, :due_for_run, site: site2, name: "Tenant 2 Source")
      end

      it "processes sources from all tenants" do
        described_class.perform_now

        expect(SerpApiIngestionJob).to have_been_enqueued.with(source_tenant1.id)
        expect(SerpApiIngestionJob).to have_been_enqueued.with(source_tenant2.id)
      end
    end
  end

  describe "job mapping" do
    it "has a mapping for serp_api_google_news" do
      expect(described_class::JOB_MAPPING["serp_api_google_news"]).to eq(SerpApiIngestionJob)
    end

    it "returns nil for unmapped kinds" do
      expect(described_class::JOB_MAPPING["rss"]).to be_nil
    end
  end

  describe "queue configuration" do
    it "uses the default queue" do
      expect(described_class.queue_name).to eq("default")
    end
  end
end
