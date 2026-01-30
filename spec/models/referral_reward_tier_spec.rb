# frozen_string_literal: true

# == Schema Information
#
# Table name: referral_reward_tiers
#
#  id                 :bigint           not null, primary key
#  active             :boolean          default(TRUE), not null
#  description        :text
#  milestone          :integer          not null
#  name               :string           not null
#  reward_data        :jsonb            not null
#  reward_type        :integer          default("digital_download"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  digital_product_id :bigint
#  site_id            :bigint           not null
#
# Indexes
#
#  index_referral_reward_tiers_on_digital_product_id     (digital_product_id)
#  index_referral_reward_tiers_on_site_id                (site_id)
#  index_referral_reward_tiers_on_site_id_and_active     (site_id,active)
#  index_referral_reward_tiers_on_site_id_and_milestone  (site_id,milestone) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (digital_product_id => digital_products.id)
#  fk_rails_...  (site_id => sites.id)
#
require "rails_helper"

RSpec.describe ReferralRewardTier, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "associations" do
    it { is_expected.to belong_to(:site) }
  end

  describe "validations" do
    subject { build(:referral_reward_tier, site: site) }

    it { is_expected.to validate_presence_of(:milestone) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:reward_type) }

    it "validates milestone is a positive integer" do
      tier = build(:referral_reward_tier, site: site, milestone: 0)
      expect(tier).not_to be_valid
      expect(tier.errors[:milestone]).to include("must be greater than 0")

      tier.milestone = -1
      expect(tier).not_to be_valid

      tier.milestone = 1.5
      expect(tier).not_to be_valid

      tier.milestone = 1
      tier.valid?
      expect(tier.errors[:milestone]).to be_empty
    end

    it "validates uniqueness of milestone scoped to site" do
      create(:referral_reward_tier, site: site, milestone: 5)
      duplicate = build(:referral_reward_tier, site: site, milestone: 5)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:milestone]).to include("already has a reward tier")
    end

    it "allows same milestone on different sites" do
      create(:referral_reward_tier, site: site, milestone: 5)

      other_tenant = create(:tenant, :enabled)
      other_site = create(:site, tenant: other_tenant)
      other_tier = build(:referral_reward_tier, site: other_site, milestone: 5)

      expect(other_tier).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:reward_type).with_values(digital_download: 0, featured_mention: 1, custom: 2) }
  end

  describe "scopes" do
    describe ".active" do
      it "returns only active tiers" do
        active_tier = create(:referral_reward_tier, site: site, active: true)
        inactive_tier = create(:referral_reward_tier, site: site, active: false)

        expect(described_class.active).to include(active_tier)
        expect(described_class.active).not_to include(inactive_tier)
      end
    end

    describe ".ordered_by_milestone" do
      it "orders by milestone ascending" do
        tier5 = create(:referral_reward_tier, site: site, milestone: 5)
        tier1 = create(:referral_reward_tier, site: site, milestone: 1)
        tier3 = create(:referral_reward_tier, site: site, milestone: 3)

        ordered = described_class.ordered_by_milestone

        expect(ordered.first).to eq(tier1)
        expect(ordered.second).to eq(tier3)
        expect(ordered.last).to eq(tier5)
      end
    end
  end

  describe "#reward_data" do
    it "returns empty hash when nil" do
      tier = build(:referral_reward_tier, site: site)
      tier[:reward_data] = nil

      expect(tier.reward_data).to eq({})
    end

    it "returns the stored hash" do
      tier = create(:referral_reward_tier, :digital_download, site: site)

      expect(tier.reward_data).to be_a(Hash)
      expect(tier.reward_data["download_url"]).to be_present
    end
  end

  describe "#download_url" do
    it "returns download_url from reward_data for digital_download tiers" do
      tier = create(:referral_reward_tier, :digital_download, site: site)

      expect(tier.download_url).to eq("https://example.com/download/bonus.pdf")
    end

    it "returns nil when not set" do
      tier = create(:referral_reward_tier, :custom, site: site)

      expect(tier.download_url).to be_nil
    end
  end

  describe "#mention_details" do
    it "returns mention_details from reward_data for featured_mention tiers" do
      tier = create(:referral_reward_tier, :featured_mention, site: site)

      expect(tier.mention_details).to eq("Featured in next newsletter")
    end

    it "returns nil when not set" do
      tier = create(:referral_reward_tier, :digital_download, site: site)

      expect(tier.mention_details).to be_nil
    end
  end

  describe "#instructions" do
    it "returns instructions from reward_data for custom tiers" do
      tier = create(:referral_reward_tier, :custom, site: site)

      expect(tier.instructions).to eq("Contact us to claim your reward")
    end

    it "returns nil when not set" do
      tier = create(:referral_reward_tier, :digital_download, site: site)

      expect(tier.instructions).to be_nil
    end
  end

  describe "SiteScoped concern" do
    it "includes SiteScoped module" do
      expect(described_class.ancestors).to include(SiteScoped)
    end
  end

  describe "factory traits" do
    it "creates valid digital_download tier" do
      tier = create(:referral_reward_tier, :digital_download, site: site)
      expect(tier).to be_valid
      expect(tier.reward_type).to eq("digital_download")
    end

    it "creates valid featured_mention tier" do
      tier = create(:referral_reward_tier, :featured_mention, site: site)
      expect(tier).to be_valid
      expect(tier.reward_type).to eq("featured_mention")
    end

    it "creates valid custom tier" do
      tier = create(:referral_reward_tier, :custom, site: site)
      expect(tier).to be_valid
      expect(tier.reward_type).to eq("custom")
    end

    it "creates valid inactive tier" do
      tier = create(:referral_reward_tier, :inactive, site: site)
      expect(tier).to be_valid
      expect(tier.active).to be false
    end
  end
end
