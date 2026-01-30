# frozen_string_literal: true

require "rails_helper"

RSpec.describe StructuredDataHelper, type: :helper do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:category) { create(:category, site: site, tenant: tenant) }

  before do
    Current.tenant = tenant
    Current.site = site
  end

  describe "#json_ld_tag" do
    it "renders a script tag with JSON-LD" do
      data = { "@type": "Organization", "name": "Test" }
      result = helper.json_ld_tag(data)

      expect(result).to include('type="application/ld+json"')
      expect(result).to include('"@type":"Organization"')
      expect(result).to include('"name":"Test"')
    end
  end

  describe "#organization_schema" do
    it "returns organization schema" do
      result = helper.organization_schema

      expect(result[:@context]).to eq("https://schema.org")
      expect(result[:@type]).to eq("Organization")
      expect(result[:name]).to eq(tenant.title)
    end
  end

  describe "#website_schema" do
    it "returns website schema with search action" do
      result = helper.website_schema

      expect(result[:@type]).to eq("WebSite")
      expect(result[:potentialAction]).to be_present
      expect(result[:potentialAction][:@type]).to eq("SearchAction")
    end
  end

  describe "#breadcrumb_schema" do
    it "returns breadcrumb list schema" do
      items = [
        { name: "Home", url: "https://example.com/" },
        { name: "Category", url: "https://example.com/category" }
      ]

      result = helper.breadcrumb_schema(items)

      expect(result[:@type]).to eq("BreadcrumbList")
      expect(result[:itemListElement].length).to eq(2)
      expect(result[:itemListElement][0][:position]).to eq(1)
      expect(result[:itemListElement][1][:position]).to eq(2)
    end

    it "returns empty hash for blank items" do
      result = helper.breadcrumb_schema([])
      expect(result).to eq({})
    end
  end

  describe "#software_schema" do
    let(:listing) { create(:listing, :tool, site: site, category: category) }

    it "returns software application schema for tools" do
      result = helper.software_schema(listing)

      expect(result[:@type]).to eq("SoftwareApplication")
      expect(result[:name]).to eq(listing.title)
    end

    it "returns empty hash for non-tool listings" do
      job_listing = create(:listing, :job, site: site, category: category)
      result = helper.software_schema(job_listing)
      expect(result).to eq({})
    end
  end

  describe "#job_posting_schema" do
    let(:listing) { create(:listing, :job, site: site, category: category, company: "Acme Inc", location: "Remote") }

    it "returns job posting schema for jobs" do
      result = helper.job_posting_schema(listing)

      expect(result[:@type]).to eq("JobPosting")
      expect(result[:title]).to eq(listing.title)
      expect(result[:hiringOrganization][:name]).to eq("Acme Inc")
    end

    it "returns empty hash for non-job listings" do
      tool_listing = create(:listing, :tool, site: site, category: category)
      result = helper.job_posting_schema(tool_listing)
      expect(result).to eq({})
    end
  end

  describe "#listing_schema" do
    it "returns software schema for tool listings" do
      listing = create(:listing, :tool, site: site, category: category)
      result = helper.listing_schema(listing)
      expect(result[:@type]).to eq("SoftwareApplication")
    end

    it "returns job posting schema for job listings" do
      listing = create(:listing, :job, site: site, category: category)
      result = helper.listing_schema(listing)
      expect(result[:@type]).to eq("JobPosting")
    end

    it "returns product schema for service listings" do
      listing = create(:listing, :service, site: site, category: category)
      result = helper.listing_schema(listing)
      expect(result[:@type]).to eq("Product")
    end
  end

  describe "#item_list_schema" do
    let(:listings) { create_list(:listing, 3, site: site, category: category) }

    it "returns item list schema" do
      result = helper.item_list_schema(listings, list_name: "Top Tools")

      expect(result[:@type]).to eq("ItemList")
      expect(result[:name]).to eq("Top Tools")
      expect(result[:numberOfItems]).to eq(3)
      expect(result[:itemListElement].length).to eq(3)
    end

    it "returns empty hash for blank items" do
      result = helper.item_list_schema([], list_name: "Empty")
      expect(result).to eq({})
    end
  end
end
