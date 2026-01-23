# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::TaxonomiesService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }
  let(:service) { described_class.new(tenant) }

  before do
    Current.tenant = tenant
    Current.site = site
  end

  describe "#initialize" do
    it "sets the tenant" do
      expect(service.instance_variable_get(:@tenant)).to eq(tenant)
    end
  end

  describe "#all_taxonomies" do
    let!(:taxonomy1) { create(:taxonomy, site: site, tenant: tenant, name: "Category A", position: 1) }
    let!(:taxonomy2) { create(:taxonomy, site: site, tenant: tenant, name: "Category B", position: 2) }
    let!(:other_tenant_taxonomy) { create(:taxonomy) }

    it "returns taxonomies for the current tenant" do
      taxonomies = service.all_taxonomies
      expect(taxonomies).to include(taxonomy1, taxonomy2)
      expect(taxonomies).not_to include(other_tenant_taxonomy)
    end

    it "includes children association" do
      taxonomies = service.all_taxonomies
      expect(taxonomies.first.association(:children)).to be_loaded
    end

    it "includes tagging_rules association" do
      taxonomies = service.all_taxonomies
      expect(taxonomies.first.association(:tagging_rules)).to be_loaded
    end

    it "orders by position" do
      taxonomies = service.all_taxonomies.to_a
      expect(taxonomies.index(taxonomy1)).to be < taxonomies.index(taxonomy2)
    end
  end

  describe "#root_taxonomies" do
    let!(:root1) { create(:taxonomy, site: site, tenant: tenant, parent: nil, position: 2) }
    let!(:root2) { create(:taxonomy, site: site, tenant: tenant, parent: nil, position: 1) }
    let!(:child) { create(:taxonomy, site: site, tenant: tenant, parent: root1) }

    it "returns only root taxonomies" do
      roots = service.root_taxonomies
      expect(roots).to include(root1, root2)
      expect(roots).not_to include(child)
    end

    it "orders by position" do
      roots = service.root_taxonomies.to_a
      expect(roots.first).to eq(root2)
      expect(roots.last).to eq(root1)
    end
  end

  describe "#find_taxonomy" do
    let!(:taxonomy) { create(:taxonomy, site: site, tenant: tenant) }

    it "finds the taxonomy by id" do
      found = service.find_taxonomy(taxonomy.id)
      expect(found).to eq(taxonomy)
    end

    it "includes tenant association" do
      found = service.find_taxonomy(taxonomy.id)
      expect(found.association(:tenant)).to be_loaded
    end

    it "includes parent association" do
      found = service.find_taxonomy(taxonomy.id)
      expect(found.association(:parent)).to be_loaded
    end

    it "includes children association" do
      found = service.find_taxonomy(taxonomy.id)
      expect(found.association(:children)).to be_loaded
    end

    it "raises error for non-existent taxonomy" do
      expect {
        service.find_taxonomy(99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "site scoping" do
    let(:other_site) { create(:site, tenant: tenant) }
    let!(:site_taxonomy) { create(:taxonomy, site: site, tenant: tenant) }
    let!(:other_site_taxonomy) { create(:taxonomy, site: other_site, tenant: tenant) }

    it "scopes to current site when set" do
      Current.site = site
      taxonomies = service.all_taxonomies
      expect(taxonomies).to include(site_taxonomy)
      expect(taxonomies).not_to include(other_site_taxonomy)
    end

    it "scopes to other site when changed" do
      Current.site = other_site
      taxonomies = service.all_taxonomies
      expect(taxonomies).to include(other_site_taxonomy)
      expect(taxonomies).not_to include(site_taxonomy)
    end
  end
end
