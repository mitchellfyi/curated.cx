# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Affiliate Redirects', type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first }
  let(:category) { create(:category, tenant: tenant, site: site) }
  let(:listing_with_affiliate) do
    create(:listing, :published, :with_affiliate,
           tenant: tenant, site: site, category: category,
           url_raw: 'https://example.com/product')
  end
  let(:listing_without_affiliate) do
    create(:listing, :published,
           tenant: tenant, site: site, category: category,
           url_raw: 'https://example.com/other')
  end

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe 'GET /go/:id' do
    context 'with a listing that has affiliate URL' do
      it 'redirects to the affiliate URL' do
        get affiliate_redirect_path(listing_with_affiliate)
        expect(response).to have_http_status(:redirect)
        expect(response.location).to start_with('https://affiliate.example.com')
      end

      it 'tracks the click' do
        expect {
          get affiliate_redirect_path(listing_with_affiliate)
        }.to change(AffiliateClick, :count).by(1)
      end

      it 'stores click metadata' do
        get affiliate_redirect_path(listing_with_affiliate),
            headers: {
              'HTTP_USER_AGENT' => 'Mozilla/5.0 Test',
              'HTTP_REFERER' => 'https://google.com/search'
            }

        click = AffiliateClick.last
        expect(click.listing).to eq(listing_with_affiliate)
        expect(click.user_agent).to eq('Mozilla/5.0 Test')
        expect(click.referrer).to eq('https://google.com/search')
        expect(click.ip_hash).to be_present
        expect(click.clicked_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'with a listing without affiliate URL' do
      it 'redirects to the canonical URL' do
        get affiliate_redirect_path(listing_without_affiliate)
        expect(response).to have_http_status(:redirect)
        expect(response.location).to eq(listing_without_affiliate.url_canonical)
      end

      it 'does not track a click' do
        expect {
          get affiliate_redirect_path(listing_without_affiliate)
        }.not_to change(AffiliateClick, :count)
      end
    end

    context 'with non-existent listing' do
      it 'redirects to root with alert' do
        get affiliate_redirect_path(id: 999_999)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t('affiliate.listing_not_found'))
      end

      it 'does not track a click' do
        expect {
          get affiliate_redirect_path(id: 999_999)
        }.not_to change(AffiliateClick, :count)
      end
    end

    context 'with listing from another site' do
      let(:other_tenant) { create(:tenant, :enabled) }
      let(:other_site) { other_tenant.sites.first }
      let(:other_category) do
        ActsAsTenant.without_tenant do
          create(:category, tenant: other_tenant, site: other_site)
        end
      end
      let(:other_listing) do
        ActsAsTenant.without_tenant do
          create(:listing, :published, :with_affiliate,
                 tenant: other_tenant, site: other_site, category: other_category)
        end
      end

      it 'redirects to root with alert' do
        get affiliate_redirect_path(other_listing)
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t('affiliate.listing_not_found'))
      end
    end

    context 'rate limiting' do
      it 'allows normal usage' do
        5.times do
          get affiliate_redirect_path(listing_with_affiliate)
          expect(response).to have_http_status(:redirect)
        end
      end

      # Note: Full rate limit testing requires more complex setup
      # The controller has rate_limit to: 100, within: 1.minute
    end

    context 'error handling during click tracking' do
      it 'still redirects even if tracking fails' do
        allow(AffiliateUrlService).to receive(:track_click_for).and_raise(StandardError.new('DB error'))

        get affiliate_redirect_path(listing_with_affiliate)
        expect(response).to have_http_status(:redirect)
        expect(response.location).to start_with('https://affiliate.example.com')
      end
    end
  end

  describe 'public access' do
    it 'does not require authentication' do
      get affiliate_redirect_path(listing_with_affiliate)
      expect(response).to have_http_status(:redirect)
      # Should redirect to affiliate URL, not login
      expect(response.location).not_to include('sign_in')
    end
  end
end
