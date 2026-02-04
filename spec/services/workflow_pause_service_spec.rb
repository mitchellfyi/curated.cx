# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkflowPauseService do
  let(:admin_user) { create(:user, :admin) }
  let(:tenant) { create(:tenant) }
  let(:tenant_admin) { create(:user).tap { |u| u.add_role(:admin, tenant) } }
  let(:regular_user) { create(:user) }
  let(:source) { create(:source, tenant: tenant) }

  describe ".paused?" do
    it "delegates to WorkflowPause.paused?" do
      expect(WorkflowPause).to receive(:paused?).with("rss_ingestion", tenant: tenant, source: nil)
      described_class.paused?(:rss_ingestion, tenant: tenant)
    end

    it "normalizes workflow type to string" do
      expect(WorkflowPause).to receive(:paused?).with("rss_ingestion", tenant: nil, source: nil)
      described_class.paused?(:rss_ingestion)
    end
  end

  describe ".pause!" do
    context "with super admin" do
      it "creates a global pause" do
        pause = described_class.pause!(:rss_ingestion, by: admin_user, reason: "Testing")

        expect(pause).to be_persisted
        expect(pause.workflow_type).to eq("rss_ingestion")
        expect(pause.tenant).to be_nil
        expect(pause.paused_by).to eq(admin_user)
        expect(pause.reason).to eq("Testing")
        expect(pause.paused_at).to be_present
      end

      it "creates a tenant-specific pause" do
        pause = described_class.pause!(:editorialisation, by: admin_user, tenant: tenant)

        expect(pause.tenant).to eq(tenant)
      end

      it "creates a source-specific pause" do
        pause = described_class.pause!(:serp_api_ingestion, by: admin_user, tenant: tenant, source: source)

        expect(pause.source).to eq(source)
      end

      it "returns existing pause if already paused at same level" do
        existing = described_class.pause!(:rss_ingestion, by: admin_user)
        duplicate = described_class.pause!(:rss_ingestion, by: admin_user)

        expect(duplicate).to eq(existing)
      end
    end

    context "with tenant admin" do
      it "can pause their own tenant" do
        pause = described_class.pause!(:editorialisation, by: tenant_admin, tenant: tenant)

        expect(pause).to be_persisted
        expect(pause.tenant).to eq(tenant)
      end

      it "cannot create global pauses" do
        expect {
          described_class.pause!(:editorialisation, by: tenant_admin)
        }.to raise_error(Pundit::NotAuthorizedError, /super admin/)
      end

      it "cannot pause other tenants" do
        other_tenant = create(:tenant)

        expect {
          described_class.pause!(:editorialisation, by: tenant_admin, tenant: other_tenant)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end

    context "with regular user" do
      it "cannot pause anything" do
        expect {
          described_class.pause!(:editorialisation, by: regular_user, tenant: tenant)
        }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
  end

  describe ".resume!" do
    let!(:pause) { described_class.pause!(:rss_ingestion, by: admin_user, tenant: tenant) }

    context "with valid permissions" do
      it "resumes the pause" do
        result = described_class.resume!(:rss_ingestion, by: admin_user, tenant: tenant)

        expect(result).to eq(pause)
        expect(pause.reload.resumed_at).to be_present
        expect(pause.resumed_by).to eq(admin_user)
      end

      it "returns nil if not paused" do
        described_class.resume!(:rss_ingestion, by: admin_user, tenant: tenant)
        result = described_class.resume!(:rss_ingestion, by: admin_user, tenant: tenant)

        expect(result).to be_nil
      end
    end

    context "with process_backlog: true" do
      let!(:pause) { described_class.pause!(:editorialisation, by: admin_user, tenant: tenant) }

      it "processes the backlog after resuming" do
        # Create some backlog items
        content_item = create(:content_item, :published, editorialised_at: nil, site: create(:site, tenant: tenant))
        source = content_item.source
        source.update!(config: { "editorialise" => true })

        expect(EditorialiseContentItemJob).to receive(:perform_later).at_least(:once)

        described_class.resume!(:editorialisation, by: admin_user, tenant: tenant, process_backlog: true)
      end
    end
  end

  describe ".backlog_size" do
    context "for editorialisation" do
      it "counts unpublished content items with editorialisation enabled" do
        site = create(:site, tenant: tenant)
        source = create(:source, site: site, tenant: tenant, config: { "editorialise" => true })

        # Published, not editorialised - should count
        create(:content_item, :published, editorialised_at: nil, site: site, source: source)
        create(:content_item, :published, editorialised_at: nil, site: site, source: source)

        # Already editorialised - should not count
        create(:content_item, :published, editorialised_at: Time.current, site: site, source: source)

        size = described_class.backlog_size(:editorialisation, tenant: tenant)
        expect(size).to eq(2)
      end
    end

    context "for ingestion workflows" do
      it "counts sources due for a run" do
        # Sources due for run
        create(:source, :rss, tenant: tenant, enabled: true, last_run_at: 2.hours.ago)
        create(:source, :rss, tenant: tenant, enabled: true, last_run_at: nil)

        # Not due
        create(:source, :rss, tenant: tenant, enabled: true, last_run_at: 30.minutes.ago)

        # Disabled
        create(:source, :rss, tenant: tenant, enabled: false, last_run_at: 2.hours.ago)

        size = described_class.backlog_size(:rss_ingestion, tenant: tenant)
        expect(size).to eq(2)
      end
    end
  end

  describe ".active_pauses" do
    let!(:global_pause) { create(:workflow_pause, tenant: nil) }
    let!(:tenant_pause) { create(:workflow_pause, tenant: tenant) }
    let!(:resolved_pause) { create(:workflow_pause, :resolved, tenant: tenant) }

    it "returns active pauses" do
      result = described_class.active_pauses

      expect(result).to include(global_pause)
      expect(result).to include(tenant_pause)
      expect(result).not_to include(resolved_pause)
    end

    it "filters by tenant when specified" do
      result = described_class.active_pauses(tenant: tenant)

      expect(result).to include(global_pause) # Global applies to all
      expect(result).to include(tenant_pause)
    end

    it "excludes global when include_global is false" do
      result = described_class.active_pauses(include_global: false)

      expect(result).not_to include(global_pause)
      expect(result).to include(tenant_pause)
    end
  end

  describe ".status_summary" do
    before do
      create(:workflow_pause, workflow_type: "rss_ingestion", tenant: nil)
      create(:workflow_pause, workflow_type: "editorialisation", tenant: tenant)
    end

    it "returns summary of active pauses" do
      summary = described_class.status_summary

      expect(summary[:total_active]).to eq(2)
      expect(summary[:by_workflow]).to include("rss_ingestion" => 1)
      expect(summary[:by_workflow]).to include("editorialisation" => 1)
      expect(summary[:global_pauses]).to eq(1)
      expect(summary[:tenant_pauses]).to eq(1)
    end

    it "includes backlog sizes for each workflow type" do
      summary = described_class.status_summary

      expect(summary[:backlogs]).to be_a(Hash)
      expect(summary[:backlogs].keys).to match_array(WorkflowPause::WORKFLOW_TYPES)
    end
  end
end
