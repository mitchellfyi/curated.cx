# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkflowPause do
  describe "associations" do
    it { is_expected.to belong_to(:tenant).optional }
    it { is_expected.to belong_to(:source).optional }
    it { is_expected.to belong_to(:paused_by).class_name("User").optional }
    it { is_expected.to belong_to(:resumed_by).class_name("User").optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:workflow_type) }

    context "when paused_at is present (active pause)" do
      subject { build(:workflow_pause, paused_at: Time.current) }

      it { is_expected.to validate_presence_of(:paused_by) }
    end

    it "requires paused_by when paused_at is set" do
      pause = build(:workflow_pause, paused_at: Time.current, paused_by: nil)
      expect(pause).not_to be_valid
      expect(pause.errors[:paused_by]).to be_present
    end

    it "does not require paused_at and paused_by when record is not paused" do
      pause = WorkflowPause.new(workflow_type: "rss_ingestion")
      pause.valid?
      expect(pause.errors[:paused_at]).to be_empty
      expect(pause.errors[:paused_by]).to be_empty
    end

    it "validates workflow_type is in allowed list" do
      pause = build(:workflow_pause, workflow_type: "invalid_type")
      expect(pause).not_to be_valid
      expect(pause.errors[:workflow_type]).to include("is not included in the list")
    end

    it "allows valid workflow types" do
      WorkflowPause::WORKFLOW_TYPES.each do |type|
        pause = build(:workflow_pause, workflow_type: type)
        expect(pause.errors[:workflow_type]).to be_empty
      end
    end

    context "source and tenant relationship" do
      let(:tenant) { create(:tenant) }
      let(:other_tenant) { create(:tenant) }
      let(:site) { create(:site, tenant: tenant) }
      let(:source) { create(:source, site: site) }

      it "is valid when source belongs to tenant" do
        pause = build(:workflow_pause, tenant: tenant, source: source)
        expect(pause).to be_valid
      end

      it "is invalid when source belongs to different tenant" do
        pause = build(:workflow_pause, tenant: other_tenant, source: source)
        expect(pause).not_to be_valid
        expect(pause.errors[:source]).to include("must belong to the specified tenant")
      end
    end
  end

  describe "scopes" do
    let!(:active_pause) { create(:workflow_pause, resumed_at: nil) }
    let!(:resolved_pause) { create(:workflow_pause, :resolved) }

    describe ".active" do
      it "returns only active pauses" do
        expect(described_class.active).to include(active_pause)
        expect(described_class.active).not_to include(resolved_pause)
      end
    end

    describe ".resolved" do
      it "returns only resolved pauses" do
        expect(described_class.resolved).to include(resolved_pause)
        expect(described_class.resolved).not_to include(active_pause)
      end
    end

    describe ".global" do
      let!(:global_pause) { create(:workflow_pause, tenant: nil) }
      let!(:tenant_pause) { create(:workflow_pause) }

      it "returns only global pauses" do
        expect(described_class.global).to include(global_pause)
        expect(described_class.global).not_to include(tenant_pause)
      end
    end
  end

  describe ".paused?" do
    let(:tenant) { create(:tenant) }
    let(:site) { create(:site, tenant: tenant) }
    let(:source) { create(:source, site: site) }

    context "with no pauses" do
      it "returns false" do
        expect(described_class.paused?("rss_ingestion")).to be false
      end
    end

    context "with a global pause" do
      before { create(:workflow_pause, workflow_type: "rss_ingestion", tenant: nil) }

      it "returns true for any tenant" do
        expect(described_class.paused?("rss_ingestion", tenant: tenant)).to be true
      end

      it "returns true with no tenant specified" do
        expect(described_class.paused?("rss_ingestion")).to be true
      end

      it "returns false for other workflow types" do
        expect(described_class.paused?("editorialisation")).to be false
      end
    end

    context "with a tenant-specific pause" do
      before { create(:workflow_pause, workflow_type: "editorialisation", tenant: tenant) }
      let(:other_tenant) { create(:tenant) }

      it "returns true for that tenant" do
        expect(described_class.paused?("editorialisation", tenant: tenant)).to be true
      end

      it "returns false for other tenants" do
        expect(described_class.paused?("editorialisation", tenant: other_tenant)).to be false
      end
    end

    context "with a source-specific pause" do
      before { create(:workflow_pause, workflow_type: "serp_api_ingestion", source: source, tenant: tenant) }
      let(:other_source) { create(:source, site: site) }

      it "returns true for that source" do
        expect(described_class.paused?("serp_api_ingestion", source: source)).to be true
      end

      it "returns false for other sources" do
        expect(described_class.paused?("serp_api_ingestion", source: other_source)).to be false
      end
    end

    context "with all_ingestion pause" do
      before { create(:workflow_pause, workflow_type: "all_ingestion", tenant: nil) }

      it "returns true for rss_ingestion" do
        expect(described_class.paused?("rss_ingestion")).to be true
      end

      it "returns true for serp_api_ingestion" do
        expect(described_class.paused?("serp_api_ingestion")).to be true
      end

      it "returns false for non-ingestion workflows" do
        expect(described_class.paused?("editorialisation")).to be false
      end
    end
  end

  describe ".find_active" do
    let(:tenant) { create(:tenant) }
    let(:site) { create(:site, tenant: tenant) }
    let(:source) { create(:source, site: site) }

    context "with overlapping pauses" do
      let!(:global_pause) { create(:workflow_pause, workflow_type: "rss_ingestion", tenant: nil) }
      let!(:tenant_pause) { create(:workflow_pause, workflow_type: "rss_ingestion", tenant: tenant) }
      let!(:source_pause) { create(:workflow_pause, workflow_type: "rss_ingestion", source: source, tenant: tenant) }

      it "returns the most specific pause (source level)" do
        result = described_class.find_active("rss_ingestion", tenant: tenant, source: source)
        expect(result).to eq(source_pause)
      end

      it "returns tenant pause when no source specified" do
        result = described_class.find_active("rss_ingestion", tenant: tenant)
        expect(result).to eq(tenant_pause)
      end

      it "returns global pause when no tenant or source specified" do
        result = described_class.find_active("rss_ingestion")
        expect(result).to eq(global_pause)
      end
    end
  end

  describe "#active?" do
    it "returns true when resumed_at is nil" do
      pause = build(:workflow_pause, resumed_at: nil)
      expect(pause.active?).to be true
    end

    it "returns false when resumed_at is present" do
      pause = build(:workflow_pause, :resolved)
      expect(pause.active?).to be false
    end
  end

  describe "#resume!" do
    let(:pause) { create(:workflow_pause) }
    let(:user) { create(:user) }

    it "sets resumed_at" do
      freeze_time do
        pause.resume!(by: user)
        expect(pause.resumed_at).to eq(Time.current)
      end
    end

    it "sets resumed_by" do
      pause.resume!(by: user)
      expect(pause.resumed_by).to eq(user)
    end
  end

  describe "#duration_text" do
    let(:pause) { create(:workflow_pause, paused_at: 2.hours.ago) }

    it "returns human-readable duration" do
      expect(pause.duration_text).to eq("2h")
    end

    context "with days" do
      let(:pause) { create(:workflow_pause, paused_at: (3.days + 5.hours).ago) }

      it "includes days and hours" do
        text = pause.duration_text
        expect(text).to include("d")
      end
    end
  end

  describe "#scope_description" do
    it "describes global pause" do
      pause = build(:workflow_pause, workflow_type: "rss_ingestion", tenant: nil)
      expect(pause.scope_description).to include("Rss Ingestion")
      expect(pause.scope_description).to include("(global)")
    end

    it "describes tenant pause" do
      tenant = build(:tenant, title: "Test Tenant")
      pause = build(:workflow_pause, workflow_type: "editorialisation", tenant: tenant)
      expect(pause.scope_description).to include("Editorialisation")
      expect(pause.scope_description).to include("Test Tenant")
    end
  end
end
