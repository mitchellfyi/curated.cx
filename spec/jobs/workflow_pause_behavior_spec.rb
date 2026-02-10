# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workflow Pause Behavior" do
  include ActiveJob::TestHelper

  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }

  describe FetchRssJob do
    let(:source) { create(:source, :rss, site: site, config: { "url" => "https://example.com/feed.xml" }) }

    context "when workflow is paused" do
      before do
        WorkflowPauseService.pause!(:rss_ingestion, by: admin_user, tenant: nil)
      end

      it "skips execution" do
        FetchRssJob.perform_now(source.id)

        source.reload
        expect(source.last_status).to eq("workflow_paused")
      end

      it "logs the pause reason" do
        allow(Rails.logger).to receive(:info).and_call_original

        FetchRssJob.perform_now(source.id)

        expect(Rails.logger).to have_received(:info).with(/Workflow paused/)
      end
    end

    context "when workflow is not paused" do
      before do
        # Stub HTTP so the job can proceed past the pause check
        stub_request(:get, "https://example.com/feed.xml")
          .to_return(status: 200, body: "<rss><channel></channel></rss>", headers: { "Content-Type" => "application/xml" })
      end

      it "executes normally (not skipped as paused)" do
        begin
          FetchRssJob.perform_now(source.id)
        rescue StandardError
          # May fail on feed parsing, but that's fine
        end

        source.reload
        expect(source.last_status).not_to eq("workflow_paused")
      end
    end

    context "when only a different tenant is paused" do
      let(:other_tenant) { create(:tenant) }

      before do
        WorkflowPauseService.pause!(:rss_ingestion, by: admin_user, tenant: other_tenant)
        stub_request(:get, "https://example.com/feed.xml")
          .to_return(status: 200, body: "<rss><channel></channel></rss>", headers: { "Content-Type" => "application/xml" })
      end

      it "executes for unpaused tenant" do
        begin
          FetchRssJob.perform_now(source.id)
        rescue StandardError
          # May fail on feed parsing, but that's fine
        end

        source.reload
        expect(source.last_status).not_to eq("workflow_paused")
      end
    end
  end

  describe SerpApiIngestionJob do
    let(:serp_source) { create(:source, :serp_api_google_news, site: site) }

    context "when serp_api_ingestion is paused" do
      before do
        WorkflowPauseService.pause!(:serp_api_ingestion, by: admin_user)
      end

      it "skips execution" do
        SerpApiIngestionJob.perform_now(serp_source.id)

        serp_source.reload
        expect(serp_source.last_status).to eq("workflow_paused")
      end
    end

    context "when all_ingestion is paused" do
      before do
        WorkflowPauseService.pause!(:all_ingestion, by: admin_user)
      end

      it "also pauses serp_api jobs" do
        SerpApiIngestionJob.perform_now(serp_source.id)

        serp_source.reload
        expect(serp_source.last_status).to eq("workflow_paused")
      end
    end
  end

  describe EditorialiseContentItemJob do
    let(:source) { create(:source, :rss, site: site) }
    let(:content_item) { create(:content_item, :published, site: site, source: source) }

    context "when editorialisation is paused" do
      before do
        WorkflowPauseService.pause!(:editorialisation, by: admin_user)
      end

      it "skips execution" do
        expect(EditorialisationService).not_to receive(:editorialise)

        EditorialiseContentItemJob.perform_now(content_item.id)
      end
    end

    context "when AI usage limit is exceeded" do
      before do
        allow(AiUsageTracker).to receive(:can_make_request?).and_return(false)
      end

      it "skips execution" do
        expect(EditorialisationService).not_to receive(:editorialise)

        EditorialiseContentItemJob.perform_now(content_item.id)
      end

      it "logs the limit exceeded" do
        allow(Rails.logger).to receive(:warn).and_call_original

        EditorialiseContentItemJob.perform_now(content_item.id)

        expect(Rails.logger).to have_received(:warn).with(/AI usage limit/)
      end
    end

    context "when not paused and within limits" do
      before do
        allow(AiUsageTracker).to receive(:can_make_request?).and_return(true)
      end

      it "executes editorialisation" do
        mock_result = instance_double(
          Editorialisation,
          completed?: true,
          input_tokens: 100,
          output_tokens: 50,
          tokens_used: 150,
          status: "completed",
          error_message: nil,
          duration_ms: 1000
        )
        allow(EditorialisationService).to receive(:editorialise).and_return(mock_result)
        allow(AiUsageTracker).to receive(:track!)

        EditorialiseContentItemJob.perform_now(content_item.id)

        expect(EditorialisationService).to have_received(:editorialise).with(content_item)
      end

      it "tracks AI usage after successful completion" do
        editorialisation = create(:editorialisation, :completed, content_item: content_item, site: site)
        allow(EditorialisationService).to receive(:editorialise).and_return(editorialisation)
        allow(AiUsageTracker).to receive(:track!)

        EditorialiseContentItemJob.perform_now(content_item.id)

        expect(AiUsageTracker).to have_received(:track!).with(
          input_tokens: 100,
          output_tokens: 50,
          editorialisation: editorialisation
        )
      end
    end
  end
end
