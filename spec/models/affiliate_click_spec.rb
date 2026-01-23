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
#  listing_id :bigint           not null
#
# Indexes
#
#  index_affiliate_clicks_on_clicked_at       (clicked_at)
#  index_affiliate_clicks_on_listing_clicked  (listing_id,clicked_at)
#  index_affiliate_clicks_on_listing_id       (listing_id)
#
# Foreign Keys
#
#  fk_rails_...  (listing_id => listings.id)
#
require 'rails_helper'

RSpec.describe AffiliateClick, type: :model do
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant) }
  let(:listing) { create(:listing, :with_affiliate, tenant: tenant, category: category) }

  describe 'associations' do
    it { should belong_to(:listing) }
  end

  describe 'validations' do
    it { should validate_presence_of(:clicked_at) }
  end

  describe 'factory' do
    it 'creates a valid affiliate click' do
      click = build(:affiliate_click, listing: listing)
      expect(click).to be_valid
    end

    it 'creates with traits' do
      click = build(:affiliate_click, :from_google, listing: listing)
      expect(click.referrer).to include('google.com')
    end
  end

  describe 'scopes' do
    let!(:click_today) { create(:affiliate_click, listing: listing, clicked_at: Time.current) }
    let!(:click_yesterday) { create(:affiliate_click, listing: listing, clicked_at: 1.day.ago) }
    let!(:click_last_week) { create(:affiliate_click, listing: listing, clicked_at: 1.week.ago) }
    let!(:click_last_month) { create(:affiliate_click, listing: listing, clicked_at: 1.month.ago) }
    let!(:click_old) { create(:affiliate_click, listing: listing, clicked_at: 2.months.ago) }

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
      let(:other_listing) { create(:listing, :with_affiliate, tenant: other_tenant, category: other_category) }
      let!(:other_click) { create(:affiliate_click, listing: other_listing) }

      it 'filters by site_id through listing' do
        site_id = listing.site_id
        expect(AffiliateClick.for_site(site_id)).to include(click_today)
        expect(AffiliateClick.for_site(site_id)).not_to include(other_click)
      end
    end
  end

  describe '.count_for_listing' do
    let!(:recent_clicks) { create_list(:affiliate_click, 3, listing: listing, clicked_at: 1.day.ago) }
    let!(:old_click) { create(:affiliate_click, listing: listing, clicked_at: 60.days.ago) }

    it 'counts clicks since the given date' do
      expect(AffiliateClick.count_for_listing(listing.id, since: 30.days.ago)).to eq(3)
    end

    it 'includes all clicks with default since' do
      expect(AffiliateClick.count_for_listing(listing.id)).to eq(3)
    end
  end

  describe '.count_by_listing' do
    let(:listing2) { create(:listing, :with_affiliate, tenant: tenant, category: category) }
    let!(:clicks_listing1) { create_list(:affiliate_click, 3, listing: listing, clicked_at: 1.day.ago) }
    let!(:clicks_listing2) { create_list(:affiliate_click, 2, listing: listing2, clicked_at: 1.day.ago) }

    it 'returns counts grouped by listing_id' do
      counts = AffiliateClick.count_by_listing(site_id: listing.site_id, since: 30.days.ago)
      expect(counts[listing.id]).to eq(3)
      expect(counts[listing2.id]).to eq(2)
    end
  end
end
