# frozen_string_literal: true

# == Schema Information
#
# Table name: affiliate_clicks
#
#  id         :bigint           not null, primary key
#  clicked_at :datetime         not null
#  ip_hash    :string
#  referrer   :text
#  user_agent :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  entry_id   :bigint           not null
#  listing_id :bigint           not null
#
# Indexes
#
#  index_affiliate_clicks_on_clicked_at       (clicked_at)
#  index_affiliate_clicks_on_entry_id         (entry_id)
#  index_affiliate_clicks_on_listing_clicked  (listing_id,clicked_at)
#  index_affiliate_clicks_on_listing_id       (listing_id)
#
# Foreign Keys
#
#  fk_rails_...  (entry_id => entries.id)
#
require 'rails_helper'

RSpec.describe AffiliateClick, type: :model do
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant) }
  let(:entry) { create(:entry, :directory, :with_affiliate, tenant: tenant, category: category) }

  describe 'associations' do
    it { should belong_to(:entry) }
  end

  describe 'validations' do
    it { should validate_presence_of(:clicked_at) }
  end

  describe 'factory' do
    it 'creates a valid affiliate click' do
      click = build(:affiliate_click, entry: entry)
      expect(click).to be_valid
    end

    it 'creates with traits' do
      click = build(:affiliate_click, :from_google, entry: entry)
      expect(click.referrer).to include('google.com')
    end
  end

  describe 'scopes' do
    let!(:click_today) { create(:affiliate_click, entry: entry, clicked_at: Time.current) }
    let!(:click_yesterday) { create(:affiliate_click, entry: entry, clicked_at: 1.day.ago) }
    let!(:click_last_week) { create(:affiliate_click, entry: entry, clicked_at: 1.week.ago) }
    let!(:click_last_month) { create(:affiliate_click, entry: entry, clicked_at: 1.month.ago) }
    let!(:click_old) { create(:affiliate_click, entry: entry, clicked_at: 2.months.ago) }

    describe '.recent' do
      it 'orders by clicked_at descending' do
        clicks = AffiliateClick.recent
        expect(clicks.first).to eq(click_today)
        expect(clicks.last).to eq(click_old)
      end
    end

    describe '.today' do
      it 'includes only clicks from today' do
        expect(AffiliateClick.today).to include(click_today)
        expect(AffiliateClick.today).not_to include(click_yesterday)
      end
    end

    describe '.this_week' do
      it 'includes clicks from the past week' do
        expect(AffiliateClick.this_week).to include(click_today)
        expect(AffiliateClick.this_week).to include(click_yesterday)
        expect(AffiliateClick.this_week).not_to include(click_last_month)
      end
    end

    describe '.this_month' do
      it 'includes clicks from the past month' do
        expect(AffiliateClick.this_month).to include(click_today)
        expect(AffiliateClick.this_month).to include(click_last_week)
        expect(AffiliateClick.this_month).not_to include(click_old)
      end
    end

    describe '.for_site' do
      let(:other_tenant) { create(:tenant) }
      let(:other_category) { create(:category, tenant: other_tenant) }
      let(:other_entry) { create(:entry, :directory, :with_affiliate, tenant: other_tenant, category: other_category) }
      let!(:other_click) { create(:affiliate_click, entry: other_entry) }

      it 'filters by site_id through entry' do
        site_id = entry.site_id
        expect(AffiliateClick.for_site(site_id)).to include(click_today)
        expect(AffiliateClick.for_site(site_id)).not_to include(other_click)
      end
    end
  end

  describe '.count_for_entry' do
    let!(:recent_clicks) { create_list(:affiliate_click, 3, entry: entry, clicked_at: 1.day.ago) }
    let!(:old_click) { create(:affiliate_click, entry: entry, clicked_at: 60.days.ago) }

    it 'counts clicks since the given date' do
      expect(AffiliateClick.count_for_entry(entry.id, since: 30.days.ago)).to eq(3)
    end

    it 'includes all clicks with default since' do
      expect(AffiliateClick.count_for_entry(entry.id)).to eq(3)
    end
  end

  describe '.count_by_entry' do
    let(:entry2) { create(:entry, :directory, :with_affiliate, tenant: tenant, category: category) }
    let!(:clicks_entry1) { create_list(:affiliate_click, 3, entry: entry, clicked_at: 1.day.ago) }
    let!(:clicks_entry2) { create_list(:affiliate_click, 2, entry: entry2, clicked_at: 1.day.ago) }

    it 'returns counts grouped by entry_id' do
      counts = AffiliateClick.count_by_entry(site_id: entry.site_id, since: 30.days.ago)
      expect(counts[entry.id]).to eq(3)
      expect(counts[entry2.id]).to eq(2)
    end
  end
end
