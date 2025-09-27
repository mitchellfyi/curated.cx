require 'rails_helper'

RSpec.describe 'Meta Tags', type: :system, js: false do
  let(:tenant) { 
    tenant = create(:tenant, 
      title: "Test Tenant", 
      description: "Test tenant description",
      slug: "test"
    )
    # Set up categories in settings
    tenant.update_setting("categories.news.enabled", true)
    tenant.update_setting("categories.apps.enabled", true)
    tenant.update_setting("categories.services.enabled", true)
    tenant
  }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe 'Application layout and structure' do
    it 'includes proper HTML structure and lang attribute' do
      visit root_path
      
      expect(page).to have_css('html[lang="en"]')
      expect(page).to have_css('head')
      expect(page).to have_css('body')
    end

    it 'includes skip link for accessibility' do
      visit root_path
      
      # Skip link should be present but hidden by default
      expect(page).to have_css('a[href="#main-content"]', visible: :hidden)
    end

    it 'includes proper landmark elements' do
      visit root_path
      
      expect(page).to have_css('header[role="banner"]')
      expect(page).to have_css('nav[role="navigation"]')
      expect(page).to have_css('main#main-content[role="main"]')
      expect(page).to have_css('footer[role="contentinfo"]')
    end
  end

  describe 'Basic meta tags' do
    it 'includes essential meta tags' do
      visit root_path
      
      # Check for viewport meta tag
      expect(page).to have_css('meta[name="viewport"]', visible: false)
      
      # Check for CSRF token
      expect(page).to have_css('meta[name="csrf-token"]', visible: false)
      
      # Check for title tag
      expect(page).to have_title(/Test Tenant/)
    end

    it 'includes favicon links' do
      visit root_path
      
      expect(page).to have_css('link[rel="icon"][href="/icon.png"]', visible: false)
      expect(page).to have_css('link[rel="icon"][href="/icon.svg"]', visible: false)
      expect(page).to have_css('link[rel="apple-touch-icon"][href="/icon.png"]', visible: false)
    end
  end

  describe 'SEO meta tags' do
    it 'includes comprehensive SEO meta tags' do
      visit root_path
      
      # Basic SEO tags
      expect(page).to have_css('meta[name="description"]', visible: false)
      expect(page).to have_css('link[rel="canonical"]', visible: false)
      
      # Check meta description content
      description_meta = page.find('meta[name="description"]', visible: false)
      expect(description_meta['content']).to eq("Test tenant description")
    end

    it 'includes keywords meta tag' do
      visit root_path
      
      expect(page).to have_css('meta[name="keywords"]', visible: false)
      keywords_meta = page.find('meta[name="keywords"]', visible: false)
      expect(keywords_meta['content']).to eq("news, apps, services")
    end
  end

  describe 'Open Graph meta tags' do
    it 'includes complete Open Graph tags' do
      visit root_path
      
      # Open Graph tags
      expect(page).to have_css('meta[property="og:title"]', visible: false)
      expect(page).to have_css('meta[property="og:description"]', visible: false)
      expect(page).to have_css('meta[property="og:type"]', visible: false)
      expect(page).to have_css('meta[property="og:url"]', visible: false)
      expect(page).to have_css('meta[property="og:site_name"]', visible: false)
      expect(page).to have_css('meta[property="og:locale"]', visible: false)
    end

    it 'has correct Open Graph content' do
      visit root_path
      
      og_title = page.find('meta[property="og:title"]', visible: false)
      expect(og_title['content']).to eq("Test Tenant")
      
      og_description = page.find('meta[property="og:description"]', visible: false)
      expect(og_description['content']).to eq("Test tenant description")
      
      og_type = page.find('meta[property="og:type"]', visible: false)
      expect(og_type['content']).to eq("website")
      
      og_site_name = page.find('meta[property="og:site_name"]', visible: false)
      expect(og_site_name['content']).to eq("Test Tenant")
    end
  end

  describe 'Twitter Card meta tags' do
    it 'includes complete Twitter Card tags' do
      visit root_path
      
      # Twitter Card tags
      expect(page).to have_css('meta[name="twitter:card"]', visible: false)
      expect(page).to have_css('meta[name="twitter:site"]', visible: false)
      expect(page).to have_css('meta[name="twitter:title"]', visible: false)
      expect(page).to have_css('meta[name="twitter:description"]', visible: false)
    end

    it 'has correct Twitter Card content' do
      visit root_path
      
      twitter_card = page.find('meta[name="twitter:card"]', visible: false)
      expect(twitter_card['content']).to eq("summary_large_image")
      
      twitter_site = page.find('meta[name="twitter:site"]', visible: false)
      expect(twitter_site['content']).to eq("@test")
      
      twitter_title = page.find('meta[name="twitter:title"]', visible: false)
      expect(twitter_title['content']).to eq("Test Tenant")
      
      twitter_description = page.find('meta[name="twitter:description"]', visible: false)
      expect(twitter_description['content']).to eq("Test tenant description")
    end
  end

  describe 'Page-specific meta tags' do
    it 'displays custom meta tags on tenant show page' do
      visit tenant_path(tenant)
      
      expect(page).to have_title(/Test Tenant/)
      expect(page).to have_css('meta[name="description"]', visible: false)
    end

    it 'displays custom meta tags on sign in page' do
      visit new_user_session_path
      
      expect(page).to have_title(/Sign In/)
      expect(page).to have_css('meta[name="description"]', visible: false)
      
      description_meta = page.find('meta[name="description"]', visible: false)
      expect(description_meta['content']).to include("Sign in to your account")
    end

    it 'displays custom meta tags on sign up page' do
      visit new_user_registration_path
      
      expect(page).to have_title(/Sign Up/)
      expect(page).to have_css('meta[name="description"]', visible: false)
      
      description_meta = page.find('meta[name="description"]', visible: false)
      expect(description_meta['content']).to include("Create a new account")
    end

    it 'displays custom meta tags on account settings page' do
      user = create(:user)
      sign_in user
      visit edit_user_registration_path
      
      expect(page).to have_title(/Account Settings/)
      expect(page).to have_css('meta[name="description"]', visible: false)
      
      description_meta = page.find('meta[name="description"]', visible: false)
      expect(description_meta['content']).to include("Manage your account settings")
    end
  end

  describe 'Fallback behavior' do
    it 'handles missing tenant gracefully' do
      allow(Current).to receive(:tenant).and_return(nil)
      visit root_path
      
      # Should still have basic meta tags
      expect(page).to have_css('meta[name="viewport"]', visible: false)
      expect(page).to have_css('meta[name="csrf-token"]', visible: false)
      
      # Should use app name as fallback
      expect(page).to have_title(/Curated/)
    end

    it 'handles tenant without description' do
      tenant_without_description = create(:tenant, 
        title: "No Description Tenant",
        description: nil,
        slug: "no_desc"
      )
      allow(Current).to receive(:tenant).and_return(tenant_without_description)
      
      visit root_path
      
      # Should still have meta tags with fallback content
      expect(page).to have_css('meta[name="description"]', visible: false)
      description_meta = page.find('meta[name="description"]', visible: false)
      expect(description_meta['content']).to eq("Curated content platform")
    end
  end

  describe 'Meta tags with tenant logo' do
    it 'includes logo in Open Graph and Twitter meta tags when available' do
      tenant_with_logo = create(:tenant,
        title: "Logo Tenant",
        description: "Tenant with logo",
        slug: "logo_tenant",
        logo_url: "https://example.com/logo.png"
      )
      allow(Current).to receive(:tenant).and_return(tenant_with_logo)
      
      visit root_path
      
      # Check for logo in Open Graph
      expect(page).to have_css('meta[property="og:image"]', visible: false)
      og_image = page.find('meta[property="og:image"]', visible: false)
      expect(og_image['content']).to eq("https://example.com/logo.png")
      
      # Check for logo in Twitter
      expect(page).to have_css('meta[name="twitter:image"]', visible: false)
      twitter_image = page.find('meta[name="twitter:image"]', visible: false)
      expect(twitter_image['content']).to eq("https://example.com/logo.png")
    end
  end
end