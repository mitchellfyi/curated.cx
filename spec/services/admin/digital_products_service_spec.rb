# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::DigitalProductsService do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { create(:site, tenant: tenant) }
  let(:service) { described_class.new }

  before do
    Current.tenant = tenant
    Current.site = site
  end

  describe "#all_products" do
    let!(:product1) { create(:digital_product, site: site, created_at: 1.day.ago) }
    let!(:product2) { create(:digital_product, site: site, created_at: 1.hour.ago) }
    let!(:other_site_product) { create(:digital_product) }

    it "returns all products ordered by recent" do
      result = service.all_products

      expect(result).to include(product1, product2)
      expect(result.first).to eq(product2) # Most recent first
    end

    it "includes site association" do
      result = service.all_products

      # Should not raise N+1 when accessing site
      expect { result.each { |p| p.site.name } }.not_to raise_error
    end
  end

  describe "#find_product" do
    let!(:product) { create(:digital_product, site: site) }

    it "finds product by id" do
      result = service.find_product(product.id)
      expect(result).to eq(product)
    end

    it "raises RecordNotFound for non-existent id" do
      expect {
        service.find_product(99999)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#create_product" do
    let(:valid_attributes) do
      {
        title: "New Product",
        description: "A great product",
        price_cents: 1999,
        status: :published
      }
    end

    it "creates a new product" do
      expect {
        service.create_product(valid_attributes)
      }.to change(DigitalProduct, :count).by(1)
    end

    it "assigns the current site" do
      product = service.create_product(valid_attributes)
      expect(product.site).to eq(site)
    end

    it "returns the created product" do
      product = service.create_product(valid_attributes)

      expect(product).to be_a(DigitalProduct)
      expect(product.title).to eq("New Product")
      expect(product.price_cents).to eq(1999)
    end

    context "with invalid attributes" do
      let(:invalid_attributes) { { title: nil } }

      it "returns the invalid product" do
        product = service.create_product(invalid_attributes)

        expect(product).not_to be_persisted
        expect(product.errors).to be_present
      end
    end
  end

  describe "#update_product" do
    let!(:product) { create(:digital_product, site: site, title: "Old Title") }

    it "updates the product" do
      service.update_product(product, { title: "New Title" })

      expect(product.reload.title).to eq("New Title")
    end

    it "returns true on success" do
      result = service.update_product(product, { title: "New Title" })
      expect(result).to be true
    end

    context "with invalid attributes" do
      it "returns false" do
        result = service.update_product(product, { title: nil })
        expect(result).to be false
      end

      it "does not update the product" do
        service.update_product(product, { title: nil })
        expect(product.reload.title).to eq("Old Title")
      end
    end
  end

  describe "#destroy_product" do
    let!(:product) { create(:digital_product, site: site) }

    it "destroys the product" do
      expect {
        service.destroy_product(product)
      }.to change(DigitalProduct, :count).by(-1)
    end

    it "returns the destroyed product" do
      result = service.destroy_product(product)
      expect(result).to eq(product)
    end
  end

  describe "#dashboard_stats" do
    context "with no data" do
      it "returns zero stats" do
        stats = service.dashboard_stats

        expect(stats[:total_revenue]).to eq(0)
        expect(stats[:total_products]).to eq(0)
        expect(stats[:published_products]).to eq(0)
        expect(stats[:draft_products]).to eq(0)
        expect(stats[:total_purchases]).to eq(0)
        expect(stats[:total_downloads]).to eq(0)
        expect(stats[:top_products]).to be_empty
      end
    end

    context "with data" do
      let!(:published_product) { create(:digital_product, :published, site: site, download_count: 10) }
      let!(:draft_product) { create(:digital_product, :draft, site: site, download_count: 5) }
      let!(:purchase1) { create(:purchase, digital_product: published_product, amount_cents: 1999) }
      let!(:purchase2) { create(:purchase, digital_product: published_product, amount_cents: 999) }
      let!(:free_purchase) { create(:purchase, :free_purchase, digital_product: draft_product) }

      it "calculates total revenue correctly" do
        stats = service.dashboard_stats
        expect(stats[:total_revenue]).to eq(2998) # 1999 + 999
      end

      it "counts products correctly" do
        stats = service.dashboard_stats

        expect(stats[:total_products]).to eq(2)
        expect(stats[:published_products]).to eq(1)
        expect(stats[:draft_products]).to eq(1)
      end

      it "counts purchases correctly" do
        stats = service.dashboard_stats
        expect(stats[:total_purchases]).to eq(3)
      end

      it "sums download count correctly" do
        stats = service.dashboard_stats
        expect(stats[:total_downloads]).to eq(15) # 10 + 5
      end

      it "returns top products ordered by purchase count" do
        stats = service.dashboard_stats

        expect(stats[:top_products].first).to eq(published_product)
        expect(stats[:top_products].first.purchases_count).to eq(2)
      end
    end

    context "with multiple sites" do
      let!(:product) { create(:digital_product, :published, site: site) }
      let!(:other_site) { create(:site, tenant: tenant) }
      let!(:other_product) { create(:digital_product, :published, site: other_site) }
      let!(:purchase) { create(:purchase, digital_product: product, amount_cents: 500) }
      let!(:other_purchase) { create(:purchase, digital_product: other_product, amount_cents: 1000) }

      it "only counts data for the current site" do
        stats = service.dashboard_stats

        expect(stats[:total_revenue]).to eq(500)
        expect(stats[:total_products]).to eq(1)
        expect(stats[:total_purchases]).to eq(1)
      end
    end
  end
end
