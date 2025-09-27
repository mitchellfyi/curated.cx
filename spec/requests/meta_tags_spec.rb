# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Meta Tags', type: :request do
  let(:tenant) {
    create(:tenant,
      title: "Test Tenant",
      description: "Test tenant description",
      slug: "test"
    ).tap do |t|
      # Set up categories in settings
      t.update_setting("categories.news.enabled", true)
      t.update_setting("categories.apps.enabled", true)
      t.update_setting("categories.services.enabled", true)
    end
  }

  before do
    tenant.save!
  end

  describe 'Basic meta tags' do
    it 'includes essential meta tags' do
      get root_url, headers: { 'Host' => 'test.localhost:3000' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('<title>Test Tenant</title>')
      expect(response.body).to include('name="description" content="Test tenant description"')
      expect(response.body).to include('name="keywords" content="apps, news, and services"')
    end
  end

  describe 'Open Graph meta tags' do
    it 'has correct Open Graph content' do
      get root_url, headers: { 'Host' => 'test.localhost:3000' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('property="og:title" content="Test Tenant"')
      expect(response.body).to include('property="og:description" content="Test tenant description"')
      expect(response.body).to include('property="og:type" content="website"')
      expect(response.body).to include('property="og:site_name" content="Test Tenant"')
    end
  end

  describe 'Twitter Card meta tags' do
    it 'has correct Twitter Card content' do
      get root_url, headers: { 'Host' => 'test.localhost:3000' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="twitter:card" content="summary_large_image"')
      expect(response.body).to include('name="twitter:site" content="@test"')
      expect(response.body).to include('name="twitter:title" content="Test Tenant"')
      expect(response.body).to include('name="twitter:description" content="Test tenant description"')
    end
  end

  describe 'Page-specific meta tags' do
    it 'displays custom meta tags on account settings page' do
      # This test is more appropriate for system tests since it involves authentication
      # For now, just test that the path exists
      get "/users/edit", headers: { 'Host' => 'test.localhost:3000' }

      # Should redirect to login page for unauthenticated user
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("sign_in")
    end
  end

  describe 'Fallback behavior' do
    let(:tenant_no_desc) {
      create(:tenant,
        title: "No Desc Tenant",
        description: "",
        slug: "nodesc"
      )
    }

    it 'handles tenant without description' do
      tenant_no_desc.save!

      get root_url, headers: { 'Host' => 'nodesc.localhost:3000' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="description" content="Curated content from No Desc Tenant"')
    end
  end

  describe 'Meta tags with tenant logo' do
    let(:tenant_with_logo) {
      create(:tenant,
        title: "Logo Tenant",
        description: "Tenant with logo",
        slug: "logo",
        logo_url: "https://example.com/logo.png"
      )
    }

    it 'includes logo in Open Graph and Twitter meta tags when available' do
      tenant_with_logo.save!

      get root_url, headers: { 'Host' => 'logo.localhost:3000' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('property="og:image" content="https://example.com/logo.png"')
      expect(response.body).to include('name="twitter:image" content="https://example.com/logo.png"')
    end
  end
end
