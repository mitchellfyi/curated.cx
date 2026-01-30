# frozen_string_literal: true

# == Schema Information
#
# Table name: network_boosts
#
#  id               :bigint           not null, primary key
#  cpc_rate         :decimal(8, 2)    not null
#  enabled          :boolean          default(TRUE), not null
#  monthly_budget   :decimal(10, 2)
#  spent_this_month :decimal(10, 2)   default(0.0)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  source_site_id   :bigint           not null
#  target_site_id   :bigint           not null
#
# Indexes
#
#  index_network_boosts_on_source_site_id                     (source_site_id)
#  index_network_boosts_on_source_site_id_and_target_site_id  (source_site_id,target_site_id) UNIQUE
#  index_network_boosts_on_target_site_id                     (target_site_id)
#  index_network_boosts_on_target_site_id_and_enabled         (target_site_id,enabled)
#
# Foreign Keys
#
#  fk_rails_...  (source_site_id => sites.id)
#  fk_rails_...  (target_site_id => sites.id)
#
require "rails_helper"

RSpec.describe NetworkBoost, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:source_site) { create(:site, tenant: tenant) }
  let(:target_site) { create(:site, tenant: tenant) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "associations" do
    it { is_expected.to belong_to(:source_site).class_name("Site") }
    it { is_expected.to belong_to(:target_site).class_name("Site") }
    it { is_expected.to have_many(:boost_impressions).dependent(:destroy) }
    it { is_expected.to have_many(:boost_clicks).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:network_boost, source_site: source_site, target_site: target_site) }

    it { is_expected.to validate_presence_of(:cpc_rate) }
    it { is_expected.to validate_numericality_of(:cpc_rate).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:monthly_budget).is_greater_than_or_equal_to(0).allow_nil }

    it "validates uniqueness of source_site scoped to target_site" do
      create(:network_boost, source_site: source_site, target_site: target_site)
      duplicate = build(:network_boost, source_site: source_site, target_site: target_site)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:source_site_id]).to include("already has a boost to this target site")
    end

    it "validates source and target are different" do
      boost = build(:network_boost, source_site: source_site, target_site: source_site)

      expect(boost).not_to be_valid
      expect(boost.errors[:target_site]).to include("must be different from source site")
    end
  end

  describe "scopes" do
    describe ".enabled" do
      it "returns only enabled boosts" do
        enabled_boost = create(:network_boost, source_site: source_site, target_site: target_site, enabled: true)
        another_target = create(:site, tenant: tenant)
        disabled_boost = create(:network_boost, source_site: source_site, target_site: another_target, enabled: false)

        expect(described_class.enabled).to include(enabled_boost)
        expect(described_class.enabled).not_to include(disabled_boost)
      end
    end

    describe ".with_budget" do
      it "returns boosts with remaining budget" do
        with_budget = create(:network_boost, source_site: source_site, target_site: target_site, monthly_budget: 100, spent_this_month: 50)

        expect(described_class.with_budget).to include(with_budget)
      end

      it "returns boosts with unlimited budget" do
        another_target = create(:site, tenant: tenant)
        unlimited = create(:network_boost, source_site: source_site, target_site: another_target, monthly_budget: nil)

        expect(described_class.with_budget).to include(unlimited)
      end

      it "excludes boosts with exhausted budget" do
        third_target = create(:site, tenant: tenant)
        exhausted = create(:network_boost, source_site: source_site, target_site: third_target, monthly_budget: 100, spent_this_month: 100)

        expect(described_class.with_budget).not_to include(exhausted)
      end
    end

    describe ".for_source_site" do
      it "filters by source site" do
        boost = create(:network_boost, source_site: source_site, target_site: target_site)

        expect(described_class.for_source_site(source_site)).to include(boost)
        expect(described_class.for_source_site(target_site)).not_to include(boost)
      end
    end

    describe ".for_target_site" do
      it "filters by target site" do
        boost = create(:network_boost, source_site: source_site, target_site: target_site)

        expect(described_class.for_target_site(target_site)).to include(boost)
        expect(described_class.for_target_site(source_site)).not_to include(boost)
      end
    end
  end

  describe "#has_budget?" do
    it "returns true when budget is nil (unlimited)" do
      boost = build(:network_boost, monthly_budget: nil)
      expect(boost.has_budget?).to be true
    end

    it "returns true when spent is less than budget" do
      boost = build(:network_boost, monthly_budget: 100, spent_this_month: 50)
      expect(boost.has_budget?).to be true
    end

    it "returns false when spent equals budget" do
      boost = build(:network_boost, monthly_budget: 100, spent_this_month: 100)
      expect(boost.has_budget?).to be false
    end

    it "returns false when spent exceeds budget" do
      boost = build(:network_boost, monthly_budget: 100, spent_this_month: 150)
      expect(boost.has_budget?).to be false
    end
  end

  describe "#remaining_budget" do
    it "returns nil when budget is unlimited" do
      boost = build(:network_boost, monthly_budget: nil)
      expect(boost.remaining_budget).to be_nil
    end

    it "returns remaining budget" do
      boost = build(:network_boost, monthly_budget: 100, spent_this_month: 30)
      expect(boost.remaining_budget).to eq(70)
    end
  end

  describe "#record_click!" do
    it "increments spent_this_month by cpc_rate" do
      boost = create(:network_boost, source_site: source_site, target_site: target_site, cpc_rate: 0.50, spent_this_month: 10)

      expect { boost.record_click! }.to change { boost.reload.spent_this_month }.from(10).to(10.50)
    end
  end

  describe "#reset_monthly_spending!" do
    it "resets spent_this_month to zero" do
      boost = create(:network_boost, source_site: source_site, target_site: target_site, spent_this_month: 50)

      expect { boost.reset_monthly_spending! }.to change { boost.reload.spent_this_month }.from(50).to(0)
    end
  end
end
