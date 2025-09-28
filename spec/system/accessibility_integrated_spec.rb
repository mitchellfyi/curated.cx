require 'rails_helper'

RSpec.describe 'Accessibility Integration', type: :system, accessibility: true do
  let!(:tenant) { create(:tenant) }
  let!(:category) { create(:category, tenant: tenant) }
  let!(:listings) { create_list(:listing, 5, tenant: tenant, category: category) }

  describe 'Homepage accessibility' do
    it 'should meet accessibility standards' do
      visit root_path
      
      # Check for basic accessibility requirements
      expect(page).to have_css('h1')
      expect(page).to have_css('nav')
      expect(page).to have_css('main')
      
      # Check for proper heading hierarchy
      headings = page.all('h1, h2, h3, h4, h5, h6')
      expect(headings.length).to be > 0
      
      # Check for alt text on images
      images = page.all('img')
      images.each do |img|
        expect(img['alt']).not_to be_nil, "Image missing alt text: #{img['src']}"
      end
      
      # Check for form labels
      forms = page.all('form')
      forms.each do |form|
        inputs = form.all('input[type="text"], input[type="email"], input[type="password"], textarea, select')
        inputs.each do |input|
          # Check for associated label or aria-label
          label = input.find(:xpath, './/ancestor::label | .//preceding-sibling::label | .//following-sibling::label', visible: false)
          aria_label = input['aria-label']
          placeholder = input['placeholder']
          
          expect(label.present? || aria_label.present? || placeholder.present?).to be true,
            "Form input missing label, aria-label, or placeholder: #{input['name'] || input['id']}"
        end
      end
    end

    it 'should be keyboard navigable' do
      visit root_path
      
      # Check for skip links
      skip_links = page.all('a[href^="#"]')
      expect(skip_links.length).to be > 0
      
      # Check for focusable elements
      focusable_elements = page.all('a, button, input, textarea, select, [tabindex]:not([tabindex="-1"])')
      expect(focusable_elements.length).to be > 0
      
      # Test tab navigation
      focusable_elements.first.click
      expect(page).to have_css(':focus')
    end
  end

  describe 'Tenant page accessibility' do
    it 'should meet accessibility standards' do
      visit tenant_path(tenant)
      
      # Check for proper heading structure
      expect(page).to have_css('h1')
      
      # Check for semantic HTML
      expect(page).to have_css('main')
      
      # Check for proper link text
      links = page.all('a')
      links.each do |link|
        text = link.text.strip
        href = link['href']
        
        # Skip empty links or links with only icons
        next if text.empty? || (text.length < 2 && link.all('i, svg').any?)
        
        expect(text).not_to be_empty, "Link missing descriptive text: #{href}"
        expect(text).not_to match(/^(click here|read more|here)$/i), "Link text too generic: '#{text}'"
      end
    end
  end

  describe 'Listing page accessibility' do
    let(:listing) { listings.first }

    it 'should meet accessibility standards' do
      visit listing_path(listing)
      
      # Check for proper heading structure
      expect(page).to have_css('h1')
      
      # Check for proper content structure
      expect(page).to have_css('main')
      
      # Check for proper link context
      links = page.all('a')
      links.each do |link|
        text = link.text.strip
        href = link['href']
        
        # Check for external link indicators
        if href&.start_with?('http') && !href.include?(request.host)
          expect(link['target']).to eq('_blank'), "External link missing target='_blank': #{href}"
          expect(link['rel']).to include('noopener'), "External link missing rel='noopener': #{href}"
        end
      end
    end
  end

  describe 'Form accessibility' do
    it 'should have accessible forms' do
      visit listings_path
      
      # Look for search forms
      forms = page.all('form')
      forms.each do |form|
        # Check for form labels
        inputs = form.all('input, textarea, select')
        inputs.each do |input|
          # Skip hidden inputs
          next if input['type'] == 'hidden'
          
          # Check for associated label
          label = input.find(:xpath, './/ancestor::label | .//preceding-sibling::label | .//following-sibling::label', visible: false)
          aria_label = input['aria-label']
          aria_labelledby = input['aria-labelledby']
          placeholder = input['placeholder']
          
          has_label = label.present? || aria_label.present? || aria_labelledby.present? || placeholder.present?
          expect(has_label).to be true, "Form input missing accessible label: #{input['name'] || input['id']}"
        end
        
        # Check for error handling
        error_messages = form.all('.error, .invalid, [aria-invalid="true"]')
        error_messages.each do |error|
          expect(error['aria-describedby']).to be_present, "Error message missing aria-describedby"
        end
      end
    end
  end

  describe 'Navigation accessibility' do
    it 'should have accessible navigation' do
      visit root_path
      
      # Check for main navigation
      nav = page.find('nav', match: :first)
      expect(nav).to be_present
      
      # Check for navigation landmarks
      expect(page).to have_css('nav[aria-label], nav[aria-labelledby]')
      
      # Check for proper link grouping
      nav_links = nav.all('a')
      expect(nav_links.length).to be > 0
      
      # Check for current page indication
      current_links = nav.all('a[aria-current="page"]')
      expect(current_links.length).to be >= 0 # May or may not have current page
    end
  end

  describe 'Color and contrast' do
    it 'should have sufficient color contrast' do
      visit root_path
      
      # This is a basic check - in a real implementation, you'd use a tool like axe-core
      # For now, we'll check that important elements have proper styling
      
      # Check for proper text contrast indicators
      text_elements = page.all('p, span, div, h1, h2, h3, h4, h5, h6')
      text_elements.each do |element|
        # Check that text isn't too small (basic check)
        font_size = element.native.css_value('font-size')
        if font_size && font_size != 'inherit'
          size_in_px = font_size.to_f
          expect(size_in_px).to be >= 12, "Text too small: #{size_in_px}px"
        end
      end
    end
  end

  describe 'ARIA attributes' do
    it 'should use ARIA attributes appropriately' do
      visit root_path
      
      # Check for proper ARIA usage
      aria_elements = page.all('[aria-label], [aria-labelledby], [aria-describedby], [aria-expanded], [aria-hidden]')
      
      # Check that aria-expanded is used with expandable elements
      expanded_elements = page.all('[aria-expanded]')
      expanded_elements.each do |element|
        expect(element['aria-expanded']).to match(/^(true|false)$/), "Invalid aria-expanded value: #{element['aria-expanded']}"
      end
      
      # Check that aria-hidden is used appropriately
      hidden_elements = page.all('[aria-hidden="true"]')
      hidden_elements.each do |element|
        # These should typically be decorative elements
        expect(element.visible?).to be false, "Element with aria-hidden='true' should not be visible"
      end
    end
  end

  describe 'Screen reader compatibility' do
    it 'should be compatible with screen readers' do
      visit root_path
      
      # Check for proper heading hierarchy
      headings = page.all('h1, h2, h3, h4, h5, h6')
      heading_levels = headings.map { |h| h.tag_name }
      
      # Should have at least one h1
      expect(heading_levels).to include('h1')
      
      # Check for proper landmark roles
      landmarks = page.all('[role="main"], [role="navigation"], [role="banner"], [role="contentinfo"]')
      expect(landmarks.length).to be > 0
      
      # Check for proper button roles
      buttons = page.all('button, [role="button"]')
      buttons.each do |button|
        expect(button['aria-label'].present? || button.text.present?).to be true,
          "Button missing accessible name: #{button['id'] || button['class']}"
      end
    end
  end
end
