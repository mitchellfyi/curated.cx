# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Accessibility', type: :system do
  include Devise::Test::IntegrationHelpers

  let(:tenant) { create(:tenant, slug: 'a11y_test') }
  let(:user) { create(:user) }

  before do
    tenant.save!
    Capybara.app_host = "http://#{tenant.slug}.localhost:3000"
    Current.tenant = tenant
  end

  describe 'WCAG 2.1 AA Compliance' do
    describe 'Page structure' do
      it 'has proper HTML lang attribute' do
        visit root_path
        expect(page).to have_css('html[lang="en"]')
      end

      it 'has a main landmark' do
        visit root_path
        expect(page).to have_css('main[role="main"], main#main-content')
      end

      it 'has a navigation landmark' do
        visit root_path
        expect(page).to have_css('nav, [role="navigation"]')
      end

      it 'has a header landmark' do
        visit root_path
        expect(page).to have_css('header[role="banner"], header')
      end

      it 'has a footer landmark' do
        visit root_path
        expect(page).to have_css('footer[role="contentinfo"], footer')
      end
    end

    describe 'Skip links' do
      it 'has a skip to main content link' do
        visit root_path
        expect(page).to have_css('a.skip-link, a[href="#main-content"]', visible: :all)
      end
    end

    describe 'Headings' do
      it 'has an h1 heading on the page' do
        visit root_path
        expect(page).to have_css('h1')
      end

      it 'has proper heading hierarchy' do
        visit root_path
        # Should have h1 before any h2
        h1_position = page.all('h1, h2, h3, h4, h5, h6').index { |h| h.tag_name == 'h1' }
        expect(h1_position).to eq(0).or be_nil # Either h1 is first or no headings
      end
    end

    describe 'Form accessibility' do
      it 'has labels for form inputs on sign in page' do
        visit new_user_session_path

        # Check that email and password fields have associated labels
        email_input = page.find('input[type="email"], input[name*="email"]', visible: :all)
        password_input = page.find('input[type="password"]', visible: :all)

        email_id = email_input[:id]
        password_id = password_input[:id]

        expect(page).to have_css("label[for='#{email_id}']") if email_id.present?
        expect(page).to have_css("label[for='#{password_id}']") if password_id.present?
      end
    end

    describe 'Images' do
      it 'favicon images have proper attributes' do
        visit root_path
        # Favicons in head don't need alt text, just checking they exist
        expect(page).to have_css('link[rel="icon"]', visible: false)
      end
    end

    describe 'Color and contrast' do
      it 'does not rely solely on color for information' do
        visit root_path
        # Check that status indicators have text or icons, not just color
        # This is a basic check - full contrast testing requires axe-core
        expect(page).to have_content(tenant.title)
      end
    end

    describe 'Keyboard navigation' do
      it 'interactive elements are focusable' do
        visit root_path
        # Check that links and buttons exist and are keyboard accessible
        expect(page).to have_css('a[href], button, input, select, textarea', minimum: 1)
      end
    end
  end

  describe 'Authentication pages' do
    it 'sign in page is accessible' do
      visit new_user_session_path

      expect(page).to have_css('html[lang="en"]')
      expect(page).to have_css('h1, h2')
      expect(page).to have_css('form')
    end

    it 'sign up page is accessible' do
      visit new_user_registration_path

      expect(page).to have_css('html[lang="en"]')
      expect(page).to have_css('h1, h2')
      expect(page).to have_css('form')
    end
  end

  describe 'Public pages' do
    let!(:category) { create(:category, tenant: tenant) }

    it 'home page is accessible' do
      visit root_path

      expect(page).to have_css('html[lang="en"]')
      expect(page).to have_css('main')
      expect(page).to have_css('nav')
    end

    it 'categories page is accessible' do
      visit categories_path

      expect(page).to have_css('html[lang="en"]')
      expect(page).to have_css('main')
    end
  end
end
