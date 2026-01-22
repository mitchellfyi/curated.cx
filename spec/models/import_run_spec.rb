# frozen_string_literal: true

# == Schema Information
#
# Table name: import_runs
#
#  id            :bigint           not null, primary key
#  completed_at  :datetime
#  error_message :text
#  items_count   :integer          default(0)
#  items_created :integer          default(0)
#  items_failed  :integer          default(0)
#  items_updated :integer          default(0)
#  started_at    :datetime         not null
#  status        :integer          default("running"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  site_id       :bigint           not null
#  source_id     :bigint           not null
#
# Indexes
#
#  index_import_runs_on_site_id                   (site_id)
#  index_import_runs_on_site_id_and_started_at    (site_id,started_at)
#  index_import_runs_on_source_id                 (source_id)
#  index_import_runs_on_source_id_and_started_at  (source_id,started_at)
#  index_import_runs_on_status                    (status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (source_id => sources.id)
#
require 'rails_helper'

RSpec.describe ImportRun, type: :model do
  describe "associations" do
    it { should belong_to(:site) }
    it { should belong_to(:source) }
  end

  describe "validations" do
    it { should validate_presence_of(:started_at) }
    it { should validate_presence_of(:status) }
    it { should validate_numericality_of(:items_count).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:items_created).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:items_updated).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:items_failed).is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }

    it "orders by started_at descending" do
      old_run = create(:import_run, site: site, source: source, started_at: 2.hours.ago)
      recent_run = create(:import_run, site: site, source: source, started_at: 1.hour.ago)

      expect(ImportRun.recent.first).to eq(recent_run)
    end

    it "filters by source" do
      source1 = create(:source, site: site)
      source2 = create(:source, site: site)

      run1 = create(:import_run, site: site, source: source1)
      run2 = create(:import_run, site: site, source: source2)

      expect(ImportRun.by_source(source1)).to include(run1)
      expect(ImportRun.by_source(source1)).not_to include(run2)
    end
  end

  describe "scoping to Site" do
    let(:tenant) { create(:tenant) }
    let(:site1) { create(:site, tenant: tenant) }
    let(:site2) { create(:site, tenant: tenant) }
    let(:source1) { create(:source, site: site1) }
    let(:source2) { create(:source, site: site2) }

    before do
      Current.site = site1
    end

    it "scopes queries to current site" do
      run1 = create(:import_run, site: site1, source: source1)
      run2 = create(:import_run, site: site2, source: source2)

      runs = ImportRun.all
      expect(runs).to include(run1)
      expect(runs).not_to include(run2)
    end
  end

  describe ".create_for_source!" do
    it "creates import run with correct attributes" do
      site = create(:site)
      source = create(:source, site: site)

      run = ImportRun.create_for_source!(source)

      expect(run.site).to eq(site)
      expect(run.source).to eq(source)
      expect(run.status).to eq("running")
      expect(run.started_at).to be_present
    end
  end

  describe "#mark_completed!" do
    it "updates status and counts" do
      run = create(:import_run, status: :running)

      run.mark_completed!(items_created: 5, items_updated: 3, items_failed: 2)

      expect(run.status).to eq("completed")
      expect(run.completed_at).to be_present
      expect(run.items_created).to eq(5)
      expect(run.items_updated).to eq(3)
      expect(run.items_failed).to eq(2)
      expect(run.items_count).to eq(10)
    end
  end

  describe "#mark_failed!" do
    it "updates status and error message" do
      run = create(:import_run, status: :running)

      run.mark_failed!("Connection timeout")

      expect(run.status).to eq("failed")
      expect(run.completed_at).to be_present
      expect(run.error_message).to eq("Connection timeout")
    end
  end

  describe "#duration" do
    it "returns duration in seconds" do
      run = create(:import_run, started_at: 5.minutes.ago, completed_at: Time.current)

      expect(run.duration).to be_within(1.second).of(5.minutes)
    end

    it "returns nil if not completed" do
      run = create(:import_run, started_at: 5.minutes.ago, completed_at: nil)

      expect(run.duration).to be_nil
    end
  end

  describe "#successful?" do
    it "returns true for completed runs with no failures" do
      run = create(:import_run, :completed, items_failed: 0)

      expect(run.successful?).to be true
    end

    it "returns false for completed runs with failures" do
      run = create(:import_run, :completed, items_failed: 2)

      expect(run.successful?).to be false
    end

    it "returns false for failed runs" do
      run = create(:import_run, :failed)

      expect(run.successful?).to be false
    end
  end
end
