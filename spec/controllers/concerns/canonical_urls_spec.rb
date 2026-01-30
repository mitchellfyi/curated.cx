# frozen_string_literal: true

require "rails_helper"

RSpec.describe CanonicalUrls, type: :controller do
  # Create a test controller that includes the concern
  controller(ApplicationController) do
    include CanonicalUrls

    # Skip Pundit callbacks for this anonymous test controller
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
      head :ok
    end

    def show
      head :ok
    end
  end

  let(:tenant) { create(:tenant, :enabled, slug: "test") }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    routes.draw do
      get "anonymous/index"
      get "anonymous/show"
    end
    Current.tenant = tenant
    Current.site = site
  end

  describe "#set_canonical_url" do
    it "sets canonical URL without excluded params" do
      get :index, params: { page: 2, sort: "latest", tag: "ruby" }

      # Page and sort should be excluded, tag should be included
      expect(controller.canonical_url).to include("/anonymous/index")
      expect(controller.canonical_url).to include("tag=ruby")
      expect(controller.canonical_url).not_to include("page=")
      expect(controller.canonical_url).not_to include("sort=")
    end

    it "sets custom canonical URL when provided" do
      get :index
      controller.set_canonical_url(url: "https://example.com/custom")

      expect(controller.canonical_url).to eq("https://example.com/custom")
    end

    it "includes only allowed params when specified" do
      get :index, params: { tag: "ruby", category: "tools", extra: "value" }
      controller.set_canonical_url(params: [ :tag ])

      expect(controller.canonical_url).to include("tag=ruby")
      expect(controller.canonical_url).not_to include("category=")
      expect(controller.canonical_url).not_to include("extra=")
    end

    it "excludes UTM tracking params" do
      get :index, params: { utm_source: "twitter", utm_medium: "social", tag: "ruby" }

      expect(controller.canonical_url).to include("tag=ruby")
      expect(controller.canonical_url).not_to include("utm_source")
      expect(controller.canonical_url).not_to include("utm_medium")
    end

    it "includes page param when include_page is true" do
      get :index, params: { page: 3, tag: "ruby" }
      controller.set_canonical_url(include_page: true)

      expect(controller.canonical_url).to include("page=3")
    end
  end

  describe "#set_pagination_links" do
    it "sets prev link when not on first page" do
      get :index, params: { page: 3 }
      controller.set_pagination_links(current_page: 3, total_pages: 10)

      expect(controller.pagination_links[:prev]).to be_present
      expect(controller.pagination_links[:prev]).to include("page=2")
    end

    it "does not set prev link on first page" do
      get :index, params: { page: 1 }
      controller.set_pagination_links(current_page: 1, total_pages: 10)

      expect(controller.pagination_links[:prev]).to be_nil
    end

    it "sets next link when not on last page" do
      get :index, params: { page: 5 }
      controller.set_pagination_links(current_page: 5, total_pages: 10)

      expect(controller.pagination_links[:next]).to be_present
      expect(controller.pagination_links[:next]).to include("page=6")
    end

    it "does not set next link on last page" do
      get :index, params: { page: 10 }
      controller.set_pagination_links(current_page: 10, total_pages: 10)

      expect(controller.pagination_links[:next]).to be_nil
    end

    it "includes base params in pagination links" do
      get :index, params: { tag: "ruby", page: 2 }
      controller.set_pagination_links(current_page: 2, total_pages: 5, base_params: { tag: "ruby" })

      expect(controller.pagination_links[:next]).to include("tag=ruby")
      expect(controller.pagination_links[:prev]).to include("tag=ruby")
    end

    it "calculates total pages from total_count and per_page" do
      get :index, params: { page: 1 }
      controller.set_pagination_links(current_page: 1, total_count: 45, per_page: 20)

      expect(controller.pagination_links[:next]).to be_present
    end

    it "removes page param from prev link when going to page 1" do
      get :index, params: { page: 2 }
      controller.set_pagination_links(current_page: 2, total_pages: 5)

      expect(controller.pagination_links[:prev]).not_to include("page=")
    end
  end

  describe "EXCLUDED_PARAMS" do
    it "includes common tracking parameters" do
      expect(CanonicalUrls::EXCLUDED_PARAMS).to include("utm_source")
      expect(CanonicalUrls::EXCLUDED_PARAMS).to include("fbclid")
      expect(CanonicalUrls::EXCLUDED_PARAMS).to include("gclid")
    end

    it "includes pagination and sorting parameters" do
      expect(CanonicalUrls::EXCLUDED_PARAMS).to include("page")
      expect(CanonicalUrls::EXCLUDED_PARAMS).to include("sort")
      expect(CanonicalUrls::EXCLUDED_PARAMS).to include("order")
    end
  end
end
