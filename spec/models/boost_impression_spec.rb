# frozen_string_literal: true

# == Schema Information
#
# Table name: boost_impressions
#
#  id               :bigint           not null, primary key
#  ip_hash          :string
#  shown_at         :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  network_boost_id :bigint           not null
#  site_id          :bigint           not null
#
# Indexes
#
#  index_boost_impressions_on_network_boost_id               (network_boost_id)
#  index_boost_impressions_on_network_boost_id_and_shown_at  (network_boost_id,shown_at)
#  index_boost_impressions_on_site_id                        (site_id)
#  index_boost_impressions_on_site_id_and_shown_at           (site_id,shown_at)
#
# Foreign Keys
#
#  fk_rails_...  (network_boost_id => network_boosts.id)
#  fk_rails_...  (site_id => sites.id)
#
require "rails_helper"

RSpec.describe BoostImpression, type: :model do
  let(:tenant) { create(:tenant, :enabled) }
  let(:source_site) { create(:site, tenant: tenant) }
  let(:target_site) { create(:site, tenant: tenant) }
  let(:network_boost) { create(:network_boost, source_site: source_site, target_site: target_site) }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
    allow(Current).to receive(:site).and_return(target_site)
  end

  describe "associations" do
    it { is_expected.to belong_to(:network_boost) }
    it { is_expected.to belong_to(:site) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:shown_at) }
  end

  describe "scopes" do
    describe ".recent" do
      it "orders by shown_at descending" do
        old_impression = create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 2.days.ago)
        new_impression = create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 1.day.ago)

        expect(described_class.recent.first).to eq(new_impression)
        expect(described_class.recent.last).to eq(old_impression)
      end
    end

    describe ".today" do
      it "returns impressions from today" do
        today_impression = create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: Time.current)
        yesterday_impression = create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 1.day.ago)

        expect(described_class.today).to include(today_impression)
        expect(described_class.today).not_to include(yesterday_impression)
      end
    end

    describe ".this_week" do
      it "returns impressions from the last week" do
        recent_impression = create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 3.days.ago)
        old_impression = create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 2.weeks.ago)

        expect(described_class.this_week).to include(recent_impression)
        expect(described_class.this_week).not_to include(old_impression)
      end
    end

    describe ".this_month" do
      it "returns impressions from the last month" do
        recent_impression = create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 2.weeks.ago)
        old_impression = create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 2.months.ago)

        expect(described_class.this_month).to include(recent_impression)
        expect(described_class.this_month).not_to include(old_impression)
      end
    end

    describe ".for_site" do
      it "filters by site" do
        impression = create(:boost_impression, network_boost: network_boost, site: target_site)

        expect(described_class.for_site(target_site)).to include(impression)
        expect(described_class.for_site(source_site)).not_to include(impression)
      end
    end

    describe ".for_boost" do
      it "filters by boost" do
        another_source = create(:site, tenant: tenant)
        another_boost = create(:network_boost, source_site: another_source, target_site: target_site)

        impression1 = create(:boost_impression, network_boost: network_boost, site: target_site)
        impression2 = create(:boost_impression, network_boost: another_boost, site: target_site)

        expect(described_class.for_boost(network_boost)).to include(impression1)
        expect(described_class.for_boost(network_boost)).not_to include(impression2)
      end
    end
  end

  describe ".count_for_boost" do
    it "returns count of impressions for a boost since given date" do
      create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 10.days.ago)
      create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 5.days.ago)
      create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 35.days.ago)

      expect(described_class.count_for_boost(network_boost.id, since: 30.days.ago)).to eq(2)
    end
  end

  describe ".count_by_date" do
    it "groups impressions by date" do
      create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: Date.current.to_datetime)
      create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: Date.current.to_datetime)
      create(:boost_impression, network_boost: network_boost, site: target_site, shown_at: 1.day.ago.to_date.to_datetime)

      result = described_class.count_by_date(since: 7.days.ago)

      # The keys might be Date objects or strings depending on database
      expect(result.values.sum).to eq(3)
      expect(result.size).to eq(2)
    end
  end
end
