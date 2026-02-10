# frozen_string_literal: true

# == Schema Information
#
# Table name: editorialisations
#
#  id                   :bigint           not null, primary key
#  ai_model             :string
#  duration_ms          :integer
#  error_message        :text
#  estimated_cost_cents :integer
#  input_tokens         :integer
#  output_tokens        :integer
#  parsed_response      :jsonb            not null
#  prompt_text          :text             not null
#  prompt_version       :string           not null
#  raw_response         :text
#  status               :integer          default("pending"), not null
#  tokens_used          :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  entry_id             :bigint           not null
#  site_id              :bigint           not null
#
# Indexes
#
#  index_editorialisations_cost_tracking              (site_id,created_at,estimated_cost_cents)
#  index_editorialisations_on_entry_id                (entry_id)
#  index_editorialisations_on_site_id                 (site_id)
#  index_editorialisations_on_site_id_and_created_at  (site_id,created_at)
#  index_editorialisations_on_site_id_and_status      (site_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (entry_id => entries.id)
#  fk_rails_...  (site_id => sites.id)
#
require "rails_helper"

RSpec.describe Editorialisation, type: :model do
  describe "associations" do
    it { should belong_to(:site) }
    it { should belong_to(:entry) }
  end

  describe "validations" do
    it { should validate_presence_of(:entry) }
    it { should validate_presence_of(:prompt_version) }
    it { should validate_presence_of(:prompt_text) }
    it { should validate_presence_of(:status) }
    it { should validate_numericality_of(:tokens_used).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:duration_ms).is_greater_than_or_equal_to(0).allow_nil }
  end

  describe "enums" do
    it "defines status enum with correct values" do
      expect(described_class.statuses).to eq({
        "pending" => 0,
        "processing" => 1,
        "completed" => 2,
        "failed" => 3,
        "skipped" => 4
      })
    end
  end

  describe "scopes" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }
    let(:entry) { create(:entry, :feed, site: site, source: source) }

    describe ".recent" do
      it "orders by created_at descending" do
        old = create(:editorialisation, entry: entry, created_at: 2.hours.ago)
        recent = create(:editorialisation, entry: create(:entry, :feed, site: site, source: source), created_at: 1.hour.ago)

        expect(Editorialisation.recent.first).to eq(recent)
      end
    end

    describe ".by_status" do
      it "filters by status" do
        pending_ed = create(:editorialisation, :pending, entry: entry)
        completed_ed = create(:editorialisation, :completed, entry: create(:entry, :feed, site: site, source: source))

        expect(Editorialisation.by_status(:pending)).to include(pending_ed)
        expect(Editorialisation.by_status(:pending)).not_to include(completed_ed)
      end
    end

    describe "status scopes" do
      let!(:pending_ed) { create(:editorialisation, :pending, entry: entry) }
      let!(:processing_ed) { create(:editorialisation, :processing, entry: create(:entry, :feed, site: site, source: source)) }
      let!(:completed_ed) { create(:editorialisation, :completed, entry: create(:entry, :feed, site: site, source: source)) }
      let!(:failed_ed) { create(:editorialisation, :failed, entry: create(:entry, :feed, site: site, source: source)) }
      let!(:skipped_ed) { create(:editorialisation, :skipped, entry: create(:entry, :feed, site: site, source: source)) }

      it ".pending returns only pending" do
        expect(Editorialisation.pending).to eq([ pending_ed ])
      end

      it ".processing returns only processing" do
        expect(Editorialisation.processing).to eq([ processing_ed ])
      end

      it ".completed returns only completed" do
        expect(Editorialisation.completed).to eq([ completed_ed ])
      end

      it ".failed returns only failed" do
        expect(Editorialisation.failed).to eq([ failed_ed ])
      end

      it ".skipped returns only skipped" do
        expect(Editorialisation.skipped).to eq([ skipped_ed ])
      end
    end
  end

  describe ".latest_for_entry" do
    let(:site) { create(:site) }
    let(:source) { create(:source, site: site) }
    let(:entry) { create(:entry, :feed, site: site, source: source) }

    it "returns the editorialisation for an entry" do
      # There's a unique constraint on entry_id, so only one editorialisation per item
      editorialisation = create(:editorialisation, entry: entry)

      expect(Editorialisation.latest_for_entry(entry.id)).to eq(editorialisation)
    end

    it "returns nil if no editorialisation exists" do
      expect(Editorialisation.latest_for_entry(0)).to be_nil
    end
  end

  describe "scoping to Site" do
    let(:tenant) { create(:tenant) }
    let(:site1) { create(:site, tenant: tenant) }
    let(:site2) { create(:site, tenant: tenant) }
    let(:source1) { create(:source, site: site1) }
    let(:source2) { create(:source, site: site2) }
    let(:entry1) { create(:entry, :feed, site: site1, source: source1) }
    let(:entry2) { create(:entry, :feed, site: site2, source: source2) }

    before do
      Current.site = site1
    end

    it "scopes queries to current site" do
      ed1 = create(:editorialisation, entry: entry1)
      ed2 = create(:editorialisation, entry: entry2)

      editorialisations = Editorialisation.all
      expect(editorialisations).to include(ed1)
      expect(editorialisations).not_to include(ed2)
    end
  end

  describe "#mark_processing!" do
    it "updates status to processing" do
      editorialisation = create(:editorialisation, :pending)

      editorialisation.mark_processing!

      expect(editorialisation.reload.status).to eq("processing")
    end
  end

  describe "#mark_completed!" do
    let(:parsed) do
      {
        "summary" => "Test summary",
        "why_it_matters" => "Test context",
        "suggested_tags" => [ "tag1", "tag2" ]
      }
    end

    it "updates all completion fields" do
      editorialisation = create(:editorialisation, :processing)

      editorialisation.mark_completed!(
        parsed: parsed,
        raw: '{"summary": "Test"}',
        tokens: 150,
        duration: 1500,
        model: "gpt-4o-mini"
      )

      editorialisation.reload
      expect(editorialisation.status).to eq("completed")
      expect(editorialisation.parsed_response).to eq(parsed)
      expect(editorialisation.raw_response).to eq('{"summary": "Test"}')
      expect(editorialisation.tokens_used).to eq(150)
      expect(editorialisation.duration_ms).to eq(1500)
      expect(editorialisation.ai_model).to eq("gpt-4o-mini")
    end
  end

  describe "#mark_failed!" do
    it "updates status and error message" do
      editorialisation = create(:editorialisation, :processing)

      editorialisation.mark_failed!("API error occurred")

      editorialisation.reload
      expect(editorialisation.status).to eq("failed")
      expect(editorialisation.error_message).to eq("API error occurred")
    end
  end

  describe "#mark_skipped!" do
    it "updates status and stores reason in error_message" do
      editorialisation = create(:editorialisation, :pending)

      editorialisation.mark_skipped!("Insufficient text")

      editorialisation.reload
      expect(editorialisation.status).to eq("skipped")
      expect(editorialisation.error_message).to eq("Insufficient text")
    end
  end

  describe "#duration_seconds" do
    it "returns duration in seconds" do
      editorialisation = build(:editorialisation, :completed, duration_ms: 1500)

      expect(editorialisation.duration_seconds).to eq(1.5)
    end

    it "returns nil if duration_ms is nil" do
      editorialisation = build(:editorialisation, duration_ms: nil)

      expect(editorialisation.duration_seconds).to be_nil
    end
  end

  describe "parsed response accessors" do
    let(:editorialisation) do
      build(:editorialisation, :completed, parsed_response: {
        "summary" => "Test summary",
        "why_it_matters" => "Important context",
        "suggested_tags" => [ "ai", "tech" ]
      })
    end

    describe "#ai_summary" do
      it "returns the summary from parsed_response" do
        expect(editorialisation.ai_summary).to eq("Test summary")
      end
    end

    describe "#why_it_matters" do
      it "returns why_it_matters from parsed_response" do
        expect(editorialisation.why_it_matters).to eq("Important context")
      end
    end

    describe "#suggested_tags" do
      it "returns suggested_tags from parsed_response" do
        expect(editorialisation.suggested_tags).to eq([ "ai", "tech" ])
      end

      it "returns empty array if not present" do
        editorialisation.parsed_response = {}
        expect(editorialisation.suggested_tags).to eq([])
      end
    end
  end

  describe "#parsed_response" do
    it "returns empty hash if nil" do
      editorialisation = build(:editorialisation)
      editorialisation.instance_variable_set(:@attributes, editorialisation.instance_variable_get(:@attributes).dup)

      # Simulate nil value
      allow(editorialisation).to receive(:read_attribute).with(:parsed_response).and_return(nil)

      expect(editorialisation.parsed_response).to eq({})
    end
  end
end
