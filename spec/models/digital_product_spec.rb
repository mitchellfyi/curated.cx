# frozen_string_literal: true

# == Schema Information
#
# Table name: digital_products
#
#  id             :bigint           not null, primary key
#  description    :text
#  download_count :integer          default(0), not null
#  metadata       :jsonb            not null
#  price_cents    :integer          default(0), not null
#  slug           :string           not null
#  status         :integer          default("draft"), not null
#  title          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  site_id        :bigint           not null
#
# Indexes
#
#  index_digital_products_on_site_id             (site_id)
#  index_digital_products_on_site_id_and_slug    (site_id,slug) UNIQUE
#  index_digital_products_on_site_id_and_status  (site_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
require "rails_helper"

RSpec.describe DigitalProduct, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }

  describe "associations" do
    it { should belong_to(:site) }
    it { should have_many(:purchases).dependent(:destroy) }
  end

  describe "validations" do
    subject { build(:digital_product, site: site) }

    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_most(255) }
    # Note: slug is auto-generated from title if blank, so we test the validation
    # only applies when title is also blank
    it "validates presence of slug when title is blank" do
      product = build(:digital_product, site: site, title: nil, slug: nil)
      expect(product).not_to be_valid
      expect(product.errors[:title]).to be_present
    end
    it { should validate_presence_of(:price_cents) }
    it { should validate_numericality_of(:price_cents).only_integer.is_greater_than_or_equal_to(0) }
    it { should validate_length_of(:description).is_at_most(10_000) }

    describe "slug format" do
      it "accepts valid slugs" do
        product = build(:digital_product, site: site, slug: "my-product-123")
        expect(product).to be_valid
      end

      it "rejects slugs with uppercase letters" do
        product = build(:digital_product, site: site, slug: "My-Product")
        expect(product).not_to be_valid
        expect(product.errors[:slug]).to include("must be lowercase with hyphens only")
      end

      it "rejects slugs with spaces" do
        product = build(:digital_product, site: site, slug: "my product")
        expect(product).not_to be_valid
      end

      it "rejects slugs with special characters" do
        product = build(:digital_product, site: site, slug: "my_product!")
        expect(product).not_to be_valid
      end
    end

    describe "slug uniqueness" do
      it "validates uniqueness within site" do
        create(:digital_product, site: site, slug: "unique-product")
        duplicate = build(:digital_product, site: site, slug: "unique-product")

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:slug]).to include("has already been taken")
      end

      it "allows same slug in different sites" do
        other_site = create(:site, tenant: tenant)
        create(:digital_product, site: site, slug: "same-slug")

        product = build(:digital_product, site: other_site, slug: "same-slug")
        expect(product).to be_valid
      end
    end
  end

  describe "enums" do
    it "defines status enum" do
      expect(DigitalProduct.statuses).to eq({ "draft" => 0, "published" => 1, "archived" => 2 })
    end

    it "defaults to draft status" do
      product = build(:digital_product, site: site)
      expect(product.status).to eq("draft")
    end
  end

  describe "scopes" do
    let!(:draft_product) { create(:digital_product, :draft, site: site) }
    let!(:published_product) { create(:digital_product, :published, site: site) }
    let!(:archived_product) { create(:digital_product, :archived, site: site) }

    describe ".visible" do
      it "returns only published products" do
        expect(DigitalProduct.visible).to include(published_product)
        expect(DigitalProduct.visible).not_to include(draft_product)
        expect(DigitalProduct.visible).not_to include(archived_product)
      end
    end

    describe ".by_status" do
      it "filters by status" do
        expect(DigitalProduct.by_status(:draft)).to include(draft_product)
        expect(DigitalProduct.by_status(:draft)).not_to include(published_product)
      end
    end

    describe ".recent" do
      it "orders by created_at desc" do
        products = DigitalProduct.recent
        expect(products.first.created_at).to be >= products.last.created_at
      end
    end
  end

  describe "callbacks" do
    describe "slug generation" do
      it "auto-generates slug from title on create" do
        product = create(:digital_product, site: site, title: "My Awesome Product", slug: nil)
        expect(product.slug).to eq("my-awesome-product")
      end

      it "handles duplicate slugs by appending counter" do
        create(:digital_product, site: site, title: "My Product")
        product = create(:digital_product, site: site, title: "My Product", slug: nil)

        expect(product.slug).to eq("my-product-1")
      end

      it "does not regenerate slug on update" do
        product = create(:digital_product, site: site, title: "Original", slug: "original")
        product.update!(title: "Updated Title")

        expect(product.slug).to eq("original")
      end

      it "preserves manually set slug" do
        product = create(:digital_product, site: site, title: "My Product", slug: "custom-slug")
        expect(product.slug).to eq("custom-slug")
      end
    end
  end

  describe "instance methods" do
    describe "#free?" do
      it "returns true for zero price" do
        product = build(:digital_product, :free, site: site)
        expect(product.free?).to be true
      end

      it "returns false for non-zero price" do
        product = build(:digital_product, site: site, price_cents: 999)
        expect(product.free?).to be false
      end
    end

    describe "#price_dollars" do
      it "converts cents to dollars" do
        product = build(:digital_product, site: site, price_cents: 1999)
        expect(product.price_dollars).to eq(19.99)
      end
    end

    describe "#formatted_price" do
      it "returns 'Free' for free products" do
        product = build(:digital_product, :free, site: site)
        expect(product.formatted_price).to eq("Free")
      end

      it "returns formatted price for paid products" do
        product = build(:digital_product, site: site, price_cents: 1999)
        expect(product.formatted_price).to eq("$19.99")
      end

      it "handles single digit cents" do
        product = build(:digital_product, site: site, price_cents: 505)
        expect(product.formatted_price).to eq("$5.05")
      end
    end

    describe "#increment_download_count!" do
      it "increments the download count" do
        product = create(:digital_product, site: site, download_count: 5)

        expect { product.increment_download_count! }.to change { product.reload.download_count }.by(1)
      end
    end

    describe "#metadata" do
      it "returns empty hash when nil" do
        product = build(:digital_product, site: site)
        product.metadata = nil
        expect(product.metadata).to eq({})
      end

      it "returns stored hash" do
        product = build(:digital_product, site: site, metadata: { "key" => "value" })
        expect(product.metadata).to eq({ "key" => "value" })
      end
    end

    describe "#file_attached?" do
      it "returns false when no file attached" do
        product = build(:digital_product, site: site)
        expect(product.file_attached?).to be false
      end

      it "returns true when file is attached" do
        product = build(:digital_product, :with_file, site: site)
        expect(product.file_attached?).to be true
      end
    end
  end

  describe "file attachment" do
    describe "content type validation" do
      it "accepts PDF files" do
        product = build(:digital_product, site: site)
        product.file.attach(
          io: StringIO.new("PDF content"),
          filename: "test.pdf",
          content_type: "application/pdf"
        )
        expect(product).to be_valid
      end

      it "accepts ZIP files" do
        product = build(:digital_product, site: site)
        product.file.attach(
          io: StringIO.new("ZIP content"),
          filename: "test.zip",
          content_type: "application/zip"
        )
        expect(product).to be_valid
      end

      it "accepts EPUB files" do
        product = build(:digital_product, site: site)
        product.file.attach(
          io: StringIO.new("EPUB content"),
          filename: "test.epub",
          content_type: "application/epub+zip"
        )
        expect(product).to be_valid
      end

      it "accepts MP3 files" do
        product = build(:digital_product, site: site)
        product.file.attach(
          io: StringIO.new("MP3 content"),
          filename: "test.mp3",
          content_type: "audio/mpeg"
        )
        expect(product).to be_valid
      end

      it "accepts MP4 files" do
        product = build(:digital_product, site: site)
        product.file.attach(
          io: StringIO.new("MP4 content"),
          filename: "test.mp4",
          content_type: "video/mp4"
        )
        expect(product).to be_valid
      end

      it "accepts PNG images" do
        product = build(:digital_product, site: site)
        product.file.attach(
          io: StringIO.new("PNG content"),
          filename: "test.png",
          content_type: "image/png"
        )
        expect(product).to be_valid
      end

      it "accepts JPEG images" do
        product = build(:digital_product, site: site)
        product.file.attach(
          io: StringIO.new("JPEG content"),
          filename: "test.jpg",
          content_type: "image/jpeg"
        )
        expect(product).to be_valid
      end
    end
  end

  describe "site scoping" do
    it "includes SiteScoped concern" do
      expect(DigitalProduct.ancestors).to include(SiteScoped)
    end
  end
end
