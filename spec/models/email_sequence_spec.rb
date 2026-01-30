# frozen_string_literal: true

# == Schema Information
#
# Table name: email_sequences
#
#  id             :bigint           not null, primary key
#  enabled        :boolean          default(FALSE), not null
#  name           :string           not null
#  trigger_config :jsonb
#  trigger_type   :integer          default("subscriber_joined"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#
# Indexes
#
#  index_email_sequences_on_site_id                               (site_id)
#  index_email_sequences_on_site_id_and_trigger_type_and_enabled  (site_id,trigger_type,enabled)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
require "rails_helper"

RSpec.describe EmailSequence, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "associations" do
    it { is_expected.to belong_to(:site) }
    it { is_expected.to have_many(:email_steps).dependent(:destroy) }
    it { is_expected.to have_many(:sequence_enrollments).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:email_sequence, site: site) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:trigger_type) }

    it "validates uniqueness of name scoped to site_id" do
      create(:email_sequence, site: site, name: "Welcome Sequence")
      duplicate = build(:email_sequence, site: site, name: "Welcome Sequence")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include("has already been taken")
    end

    it "allows same name for different sites" do
      other_site = create(:site, tenant: tenant)
      create(:email_sequence, site: site, name: "Welcome Sequence")
      other_sequence = build(:email_sequence, site: other_site, name: "Welcome Sequence")

      expect(other_sequence).to be_valid
    end
  end

  describe "enums" do
    it { is_expected.to define_enum_for(:trigger_type).with_values(subscriber_joined: 0, referral_milestone: 1) }
  end

  describe "scopes" do
    describe ".enabled" do
      let!(:enabled_sequence) { create(:email_sequence, :enabled, site: site) }
      let!(:disabled_sequence) { create(:email_sequence, site: site, enabled: false) }

      it "returns only enabled sequences" do
        expect(described_class.enabled).to include(enabled_sequence)
        expect(described_class.enabled).not_to include(disabled_sequence)
      end
    end

    describe ".for_trigger" do
      let!(:subscriber_sequence) { create(:email_sequence, site: site, trigger_type: :subscriber_joined) }
      let!(:referral_sequence) { create(:email_sequence, :referral_milestone_trigger, site: site) }

      it "filters by trigger type" do
        expect(described_class.for_trigger(:subscriber_joined)).to include(subscriber_sequence)
        expect(described_class.for_trigger(:subscriber_joined)).not_to include(referral_sequence)
        expect(described_class.for_trigger(:referral_milestone)).to include(referral_sequence)
        expect(described_class.for_trigger(:referral_milestone)).not_to include(subscriber_sequence)
      end
    end
  end

  describe "#trigger_config" do
    it "returns empty hash with indifferent access when nil" do
      sequence = build(:email_sequence, site: site, trigger_config: nil)

      expect(sequence.trigger_config).to eq({})
      expect(sequence.trigger_config[:any_key]).to be_nil
    end

    it "returns config with indifferent access" do
      sequence = build(:email_sequence, :referral_milestone_trigger, site: site)

      expect(sequence.trigger_config[:milestone]).to eq(3)
      expect(sequence.trigger_config["milestone"]).to eq(3)
    end
  end

  describe "SiteScoped concern" do
    it "includes SiteScoped module" do
      expect(described_class.ancestors).to include(SiteScoped)
    end
  end

  describe "factory" do
    it "creates a valid email sequence" do
      sequence = build(:email_sequence, site: site)
      expect(sequence).to be_valid
    end

    it "creates a valid sequence with :enabled trait" do
      sequence = build(:email_sequence, :enabled, site: site)
      expect(sequence).to be_valid
      expect(sequence.enabled).to be true
    end

    it "creates a valid sequence with :with_steps trait" do
      sequence = create(:email_sequence, :with_steps, site: site)
      expect(sequence.email_steps.count).to eq(3)
    end

    it "creates a valid sequence with :referral_milestone_trigger trait" do
      sequence = build(:email_sequence, :referral_milestone_trigger, site: site)
      expect(sequence).to be_valid
      expect(sequence.trigger_type).to eq("referral_milestone")
      expect(sequence.trigger_config[:milestone]).to eq(3)
    end
  end
end
