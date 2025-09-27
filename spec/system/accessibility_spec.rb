require 'rails_helper'

RSpec.describe 'Accessibility', type: :system do
  let(:tenant) {
    create(:tenant,
      title: "Test Tenant",
      description: "Test tenant description",
      slug: "test"
    )
  }

  before do
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

    # Set up the tenant in the database so the tenant resolver can find it
    tenant.save!
    # Clear current tenant before the test
    Current.reset
    # Use localhost with tenant slug as subdomain for system tests
    Capybara.app_host = "http://#{tenant.slug}.localhost:3000"
  end

  describe 'Home page' do
    it 'meets WCAG accessibility standards' do
      visit root_path
      expect(page).to be_accessible
    end
  end

  describe 'Error pages' do
    it '404 page meets accessibility standards' do
      visit '/non-existent-page'
      expect(page).to be_accessible
    end
  end

  describe 'Navigation' do
    it 'main navigation is accessible' do
      visit root_path

      # Check for skip links
      expect(page).to have_css('a[href="#main-content"]', text: I18n.t('a11y.skip_to_content'), visible: false)

      # Check navigation landmarks
      expect(page).to have_css('nav[role="navigation"], nav[aria-label]')
      expect(page).to have_css('main[role="main"], main')
    end
  end

  describe 'Forms' do
    context 'when forms are present' do
      it 'forms have proper labels and structure' do
        # This will be expanded when we have actual forms
        visit root_path

        # Check that any forms have proper labeling
        forms = page.all('form')
        forms.each do |form|
          inputs = form.all('input[type="text"], input[type="email"], input[type="password"], textarea, select')
          inputs.each do |input|
            input_id = input[:id]
            expect(page).to have_css("label[for='#{input_id}']") if input_id
          end
        end
      end
    end
  end

  describe 'Color contrast and visual design' do
    it 'meets color contrast requirements', :js do
      visit root_path

      # Use axe-core to check color contrast
      expect(page).to be_axe_clean.according_to(:wcag2aa).checking(:color_contrast)
    end
  end

  describe 'Keyboard navigation' do
    it 'supports keyboard navigation', :js do
      visit root_path

      # Check that focusable elements can receive focus
      focusable_elements = page.all('a, button, input, textarea, select, [tabindex]:not([tabindex="-1"])')

      expect(focusable_elements.count).to be > 0, 'Page should have focusable elements'

      # Test tab navigation (simplified test)
      first_focusable = focusable_elements.first
      first_focusable.send_keys(:tab)

      # Verify focus management is working
      expect(page).to be_axe_clean.according_to(:wcag2aa).checking(:keyboard)
    end
  end
end
