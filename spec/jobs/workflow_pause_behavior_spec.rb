# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Workflow Pause Behavior" do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:source) { create(:source, :rss, site: site, tenant: tenant) }
  let(:admin_user) { create(:user, :admin) }

  describe FetchRssJob do
    context "when workflow is paused" do
      before do
        WorkflowPauseService.pause!(:rss_ingestion, by: admin_user, tenant: nil)
      end

      it "skips execution" do
        expect(source).not_to receive(:update_run_status).with("success")
        expect(source).to receive(:update_run_status).with("workflow_paused")

        FetchRssJob.perform_now(source.id)
      end

      it "logs the pause reason" do
        expect(Rails.logger).to receive(:info).with(/Workflow paused/)

        FetchRssJob.perform_now(source.id)
      end
    end

    context "when workflow is not paused" do
      it "executes normally" do
        # Allow the job to fail on HTTP/config - we're testing it actually runs (not skipped)
        # ConfigurationError inherits from StandardError, so this catches both
        expect {
          FetchRssJob.perform_now(source.id)
        }.to raise_error(StandardError)
      end
    end

    context "when only a different tenant is paused" do
      let(:other_tenant) { create(:tenant) }

      before do
        WorkflowPauseService.pause!(:rss_ingestion, by: admin_user, tenant: other_tenant)
      end

      it "executes for unpaused tenant" do
        expect(source).not_to receive(:update_run_status).with("workflow_paused")

        expect {
          FetchRssJob.perform_now(source.id)
        }.to raise_error(StandardError)
      end
    end
  end

  describe SerpApiIngestionJob do
    let(:serp_source) { create(:source, :serp_api_google_news, site: site, tenant: tenant) }

    context "when serp_api_ingestion is paused" do
      before do
        WorkflowPauseService.pause!(:serp_api_ingestion, by: admin_user)
      end

      it "skips execution" do
        expect(serp_source).to receive(:update_run_status).with("workflow_paused")

        SerpApiIngestionJob.perform_now(serp_source.id)
      end
    end

    context "when all_ingestion is paused" do
      before do
        WorkflowPauseService.pause!(:all_ingestion, by: admin_user)
      end

      it "also pauses serp_api jobs" do
        expect(serp_source).to receive(:update_run_status).with("workflow_paused")

        SerpApiIngestionJob.perform_now(serp_source.id)
      end
    end
  end

  describe EditorialiseContentItemJob do
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
        expect(Rails.logger).to receive(:warn).with(/AI usage limit/)

        EditorialiseContentItemJob.perform_now(content_item.id)
      end
    end

    context "when not paused and within limits" do
      before do
        allow(AiUsageTracker).to receive(:can_make_request?).and_return(true)
      end

      it "executes editorialisation" do
        mock_result = instance_double(Editorialisation, completed?: true, input_tokens: 100, output_tokens: 50, tokens_used: 150, status: "completed", error_message: nil, duration_ms: 1000)
        allow(EditorialisationService).to receive(:editorialise).and_return(mock_result)
        allow(AiUsageTracker).to receive(:track!)

        EditorialiseContentItemJob.perform_now(content_item.id)

        expect(EditorialisationService).to have_received(:editorialise).with(content_item)
      end

      it "tracks AI usage after successful completion" do
        editorialisation = create(:editorialisation, :completed, content_item: content_item, site: site)
        allow(EditorialisationService).to receive(:editorialise).and_return(editorialisation)

        expect(AiUsageTracker).to receive(:track!).with(
          input_tokens: 100,
          output_tokens: 50,
          editorialisation: editorialisation
        )

        EditorialiseContentItemJob.perform_now(content_item.id)
      end
    end
  end
end
