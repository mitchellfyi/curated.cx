# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Share Buttons", type: :system do
  include Devise::Test::IntegrationHelpers

  let(:tenant) { create(:tenant, :enabled, slug: "test") }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:category) { create(:category, site: site, tenant: tenant) }
  let(:entry) { create(:entry, :directory, :tool, site: site, category: category, title: "Test Tool") }

  before do
    tenant.save!
    Current.reset
    Capybara.app_host = "http://#{tenant.slug}.localhost:3000"
    Current.tenant = tenant
    Current.site = site
  end

  describe "Entry show page" do
    it "renders share buttons container" do
      visit listing_path(entry)

      expect(page).to have_css('[data-controller~="share"]')
    end

    it "renders Twitter/X share link with correct URL" do
      visit listing_path(entry)

      twitter_link = page.find('a[title="' + I18n.t("share.twitter") + '"]')
      expect(twitter_link[:href]).to include("twitter.com/intent/tweet")
      expect(twitter_link[:href]).to include("%2Flistings%2F#{entry.id}")
      expect(twitter_link[:href]).to include(CGI.escape(entry.title))
      expect(twitter_link[:target]).to eq("_blank")
      expect(twitter_link[:rel]).to include("noopener")
    end

    it "renders LinkedIn share link with correct URL" do
      visit listing_path(entry)

      linkedin_link = page.find('a[title="' + I18n.t("share.linkedin") + '"]')
      expect(linkedin_link[:href]).to include("linkedin.com/sharing/share-offsite")
      expect(linkedin_link[:href]).to include("%2Flistings%2F#{entry.id}")
      expect(linkedin_link[:target]).to eq("_blank")
    end

    it "renders Facebook share link with correct URL" do
      visit listing_path(entry)

      facebook_link = page.find('a[title="' + I18n.t("share.facebook") + '"]')
      expect(facebook_link[:href]).to include("facebook.com/sharer/sharer.php")
      expect(facebook_link[:href]).to include("%2Flistings%2F#{entry.id}")
      expect(facebook_link[:target]).to eq("_blank")
    end

    it "renders copy link button with correct data attributes" do
      visit listing_path(entry)

      copy_button = page.find('button[title="' + I18n.t("share.copy_link") + '"]')
      expect(copy_button["data-action"]).to include("click->share#copyLink")
      expect(copy_button["data-share-url-value"]).to include("/listings/#{entry.id}")
    end

    it "renders native share button (hidden by default)" do
      visit listing_path(entry)

      native_button = page.find('button[title="' + I18n.t("share.native") + '"]', visible: :all)
      expect(native_button["data-action"]).to include("click->share#nativeShare")
      expect(native_button["data-share-target"]).to eq("nativeButton")
      expect(native_button[:class]).to include("hidden")
    end

    it "includes screen reader accessible labels" do
      visit listing_path(entry)

      expect(page).to have_css('a[title="' + I18n.t("share.twitter") + '"] .sr-only', text: I18n.t("share.twitter"), visible: :all)
      expect(page).to have_css('a[title="' + I18n.t("share.linkedin") + '"] .sr-only', text: I18n.t("share.linkedin"), visible: :all)
      expect(page).to have_css('a[title="' + I18n.t("share.facebook") + '"] .sr-only', text: I18n.t("share.facebook"), visible: :all)
      expect(page).to have_css('button[title="' + I18n.t("share.copy_link") + '"] .sr-only', text: I18n.t("share.copy_link"), visible: :all)
    end
  end
end
