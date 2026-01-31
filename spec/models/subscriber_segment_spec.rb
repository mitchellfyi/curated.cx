# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriber_segments
#
#  id             :bigint           not null, primary key
#  description    :text
#  enabled        :boolean          default(TRUE), not null
#  name           :string           not null
#  rules          :jsonb            not null
#  system_segment :boolean          default(FALSE), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#  tenant_id      :bigint           not null
#
# Indexes
#
#  index_subscriber_segments_on_site_id                     (site_id)
#  index_subscriber_segments_on_site_id_and_enabled         (site_id,enabled)
#  index_subscriber_segments_on_site_id_and_system_segment  (site_id,system_segment)
#  index_subscriber_segments_on_tenant_id                   (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
require "rails_helper"

RSpec.describe SubscriberSegment, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(site)
  end

  describe "validations" do
    it "validates presence of name" do
      segment = build(:subscriber_segment, site: site, name: nil)

      expect(segment).not_to be_valid
      expect(segment.errors[:name]).to include("can't be blank")
    end

    it "validates name length" do
      segment = build(:subscriber_segment, site: site, name: "a" * 101)

      expect(segment).not_to be_valid
      expect(segment.errors[:name]).to include("is too long (maximum is 100 characters)")
    end
  end

  describe "scopes" do
    describe ".enabled" do
      it "returns only enabled segments" do
        enabled = create(:subscriber_segment, site: site, enabled: true)
        disabled = create(:subscriber_segment, site: site, enabled: false)

        expect(described_class.enabled).to include(enabled)
        expect(described_class.enabled).not_to include(disabled)
      end
    end

    describe ".system" do
      it "returns only system segments" do
        system_seg = create(:subscriber_segment, :system, site: site)
        custom_seg = create(:subscriber_segment, site: site, system_segment: false)

        expect(described_class.system).to include(system_seg)
        expect(described_class.system).not_to include(custom_seg)
      end
    end

    describe ".custom" do
      it "returns only custom (non-system) segments" do
        system_seg = create(:subscriber_segment, :system, site: site)
        custom_seg = create(:subscriber_segment, site: site, system_segment: false)

        expect(described_class.custom).to include(custom_seg)
        expect(described_class.custom).not_to include(system_seg)
      end
    end
  end

  describe "#rules" do
    it "returns empty hash when rules is nil" do
      segment = build(:subscriber_segment, site: site, rules: nil)
      expect(segment.rules).to eq({})
    end

    it "returns the rules hash when set" do
      rules = { "active" => true, "frequency" => "weekly" }
      segment = build(:subscriber_segment, site: site, rules: rules)

      expect(segment.rules).to eq(rules)
    end
  end

  describe "#editable?" do
    it "returns true for custom segments" do
      segment = create(:subscriber_segment, site: site, system_segment: false)
      expect(segment.editable?).to be true
    end

    it "returns false for system segments" do
      segment = create(:subscriber_segment, :system, site: site)
      expect(segment.editable?).to be false
    end
  end

  describe "#subscribers_count" do
    it "returns the count of matching subscribers" do
      segment = create(:subscriber_segment, site: site, rules: {})
      user1 = create(:user)
      user2 = create(:user)
      create(:digest_subscription, user: user1, site: site)
      create(:digest_subscription, user: user2, site: site)

      expect(segment.subscribers_count).to eq(2)
    end
  end

  describe "associations" do
    it "belongs to site" do
      segment = create(:subscriber_segment, site: site)
      expect(segment.site).to eq(site)
    end

    it "belongs to tenant" do
      segment = create(:subscriber_segment, site: site, tenant: tenant)
      expect(segment.tenant).to eq(tenant)
    end
  end

  describe "default values" do
    it "defaults enabled to true" do
      segment = described_class.new(name: "Test", site: site, tenant: tenant)
      expect(segment.enabled).to be true
    end

    it "defaults system_segment to false" do
      segment = described_class.new(name: "Test", site: site, tenant: tenant)
      expect(segment.system_segment).to be false
    end

    it "defaults rules to empty hash" do
      segment = described_class.new(name: "Test", site: site, tenant: tenant)
      segment.save!
      expect(segment.rules).to eq({})
    end
  end
end
