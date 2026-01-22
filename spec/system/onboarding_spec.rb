# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Onboarding Flow", type: :system do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :admin) }
  let(:tenant) { create(:tenant, slug: "onboarding_test") }

  before do
    # Ensure tenant is saved
    tenant.save!

    # Set Capybara to use the tenant's hostname so the middleware can resolve it
    Capybara.app_host = "http://#{tenant.slug}.localhost:3000"

    # Sign in user
    sign_in user

    # Set tenant context (for tests that don't go through the middleware)
    Current.tenant = tenant
  end

  describe "Creating a new site" do
    it "allows a signed-in tenant to create a new site" do
      visit admin_sites_path

      # Click "New Site" button
      click_link "New Site"

      # Fill in site form
      fill_in "Name", with: "AI News"
      fill_in "Slug", with: "ai_news"
      fill_in "Description", with: "Curated AI industry news and insights"
      fill_in "Topic Tags", with: "ai, machine-learning, technology"

      # Submit form
      click_button "Create Site"

      # Should redirect to site show page
      expect(page).to have_content("AI News")
      expect(page).to have_content("Curated AI industry news and insights")
      expect(page).to have_content("ai")
      expect(page).to have_content("machine-learning")
      expect(page).to have_content("technology")

      # Verify site was created
      site = Site.find_by(slug: "ai_news")
      expect(site).to be_present
      expect(site.name).to eq("AI News")
      expect(site.topics).to contain_exactly("ai", "machine-learning", "technology")
    end

    it "shows validation errors for invalid site data" do
      visit new_admin_site_path

      # Try to submit without required fields
      click_button "Create Site"

      # Should show validation errors
      expect(page).to have_content("can't be blank")
    end
  end

  describe "Adding a domain to a site" do
    let!(:site) { create(:site, tenant: tenant, slug: "ai_news", name: "AI News") }

    it "allows adding an apex domain and shows DNS instructions" do
      visit admin_site_path(site)

      # Click first "Add Domain" button (in the Domains section)
      click_link "Add Domain", match: :first

      # Fill in apex domain
      fill_in "Domain", with: "ainews.cx"

      # Submit form
      click_button "Add Domain"

      # Should redirect to site show page with success message
      expect(page).to have_content("Domain added successfully")
      expect(page).to have_content("ainews.cx")

      # Click to view DNS instructions
      click_link "View DNS Instructions"

      # Should show DNS Configuration page
      expect(page).to have_content("DNS Configuration")

      # Should show A record instructions for apex domain
      expect(page).to have_content("A Record Configuration")
      expect(page).to have_content("ALIAS/ANAME Record")
    end

    it "allows adding a subdomain and shows CNAME instructions" do
      visit admin_site_path(site)

      # Click first "Add Domain" button (in the Domains section)
      click_link "Add Domain", match: :first

      # Fill in subdomain
      fill_in "Domain", with: "news.ainews.cx"

      # Submit form
      click_button "Add Domain"

      # Should redirect to site show page with success message
      expect(page).to have_content("Domain added successfully")
      expect(page).to have_content("news.ainews.cx")

      # Click to view DNS instructions
      click_link "View DNS Instructions"

      # Should show DNS Configuration page
      expect(page).to have_content("DNS Configuration")

      # Should show CNAME instructions for subdomain
      expect(page).to have_content("CNAME Record Configuration")
    end

    it "shows DNS check button" do
      domain = create(:domain, site: site, hostname: "ainews.cx")
      visit admin_site_domain_path(site, domain)

      # Should have "Check DNS" button
      expect(page).to have_button("Check DNS")
    end

    it "handles DNS check (even if it fails)" do
      domain = create(:domain, site: site, hostname: "ainews.cx")
      visit admin_site_domain_path(site, domain)

      # Click "Check DNS" button
      click_button "Check DNS"

      # Should show DNS check results (may show "no records found" which is expected)
      expect(page).to have_content("DNS Check Results")
      expect(page).to have_content("Checked at")
    end
  end

  describe "Complete onboarding flow" do
    it "allows creating a site and adding a domain in sequence" do
      # Step 1: Create site
      visit admin_sites_path
      click_link "New Site"

      fill_in "Name", with: "Tech News"
      fill_in "Slug", with: "tech_news"
      fill_in "Description", with: "Latest technology news"
      fill_in "Topic Tags", with: "technology, startups"

      click_button "Create Site"

      # Verify site created
      expect(page).to have_content("Tech News")
      site = Site.find_by(slug: "tech_news")
      expect(site).to be_present

      # Step 2: Add domain
      click_link "Add Domain", match: :first

      fill_in "Domain", with: "technews.cx"
      click_button "Add Domain"

      # Should redirect to site page with success message
      expect(page).to have_content("Domain added successfully")
      expect(page).to have_content("technews.cx")

      # Click to view DNS instructions
      click_link "View DNS Instructions"

      # Verify DNS instructions shown
      expect(page).to have_content("DNS Configuration")
      expect(page).to have_content("A Record Configuration")

      # Verify domain was created
      site.reload
      domain = site.domains.find_by(hostname: "technews.cx")
      expect(domain).to be_present
      # Note: primary status depends on whether other domains exist
      # In this flow, it should be true as it's the first custom domain
      expect(site.domains.count).to eq(1)
    end
  end
end
