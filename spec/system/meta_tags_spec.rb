require 'rails_helper'

RSpec.describe 'Meta Tags', type: :system, js: false do
  describe 'Application layout' do
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

  describe 'Meta tags rendering' do
    it 'includes basic meta tags' do
      visit root_path
      
      # Check for viewport meta tag
      expect(page).to have_css('meta[name="viewport"]', visible: false)
      
      # Check for CSRF token
      expect(page).to have_css('meta[name="csrf-token"]', visible: false)
      
      # Check for title tag
      expect(page).to have_title(/Curated/)
    end

    it 'includes SEO meta tags' do
      visit root_path
      
      # Basic SEO tags should be present
      expect(page).to have_css('meta[name="description"]', visible: false)
      expect(page).to have_css('link[rel="canonical"]', visible: false)
    end
  end
end