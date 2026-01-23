# frozen_string_literal: true

# == Schema Information
#
# Table name: taxonomies
#
#  id          :bigint           not null, primary key
#  description :text
#  name        :string           not null
#  position    :integer          default(0), not null
#  slug        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  parent_id   :bigint
#  site_id     :bigint           not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_taxonomies_on_site_id                (site_id)
#  index_taxonomies_on_site_id_and_parent_id  (site_id,parent_id)
#  index_taxonomies_on_site_id_and_slug       (site_id,slug) UNIQUE
#  index_taxonomies_on_tenant_id              (tenant_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => taxonomies.id)
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
require "rails_helper"

RSpec.describe Taxonomy, type: :model do
  describe "associations" do
    it { should belong_to(:site) }
    it { should belong_to(:tenant) }
    it { should belong_to(:parent).class_name("Taxonomy").optional }
    it { should have_many(:children).class_name("Taxonomy").with_foreign_key(:parent_id).dependent(:destroy) }
    it { should have_many(:tagging_rules).dependent(:destroy) }
  end

  describe "validations" do
    let(:tenant) { create(:tenant) }
    let(:site) { create(:site, tenant: tenant) }
    subject { create(:taxonomy, site: site, tenant: tenant) }

    it { should validate_presence_of(:name) }
    # Slug is auto-generated from name, so presence validation test doesn't work with shoulda
    it { should validate_uniqueness_of(:slug).scoped_to(:site_id) }

    it "validates slug format" do
      taxonomy = build(:taxonomy, site: site, slug: "Valid-slug-123")
      expect(taxonomy).not_to be_valid
      expect(taxonomy.errors[:slug]).to include("only allows lowercase letters, numbers, and hyphens")
    end

    it "allows valid slug format" do
      taxonomy = build(:taxonomy, site: site, slug: "valid-slug-123")
      expect(taxonomy).to be_valid
    end
  end

  describe "callbacks" do
    describe "#generate_slug_from_name" do
      let(:site) { create(:site) }

      it "generates slug from name when slug is blank" do
        taxonomy = build(:taxonomy, site: site, name: "Ruby on Rails", slug: nil)
        taxonomy.valid?
        expect(taxonomy.slug).to eq("ruby-on-rails")
      end

      it "does not override existing slug" do
        taxonomy = build(:taxonomy, site: site, name: "Ruby on Rails", slug: "custom-slug")
        taxonomy.valid?
        expect(taxonomy.slug).to eq("custom-slug")
      end

      it "handles special characters in name" do
        taxonomy = build(:taxonomy, site: site, name: "AI & Machine Learning!", slug: nil)
        taxonomy.valid?
        expect(taxonomy.slug).to eq("ai-machine-learning")
      end
    end

    # Note: #set_tenant_from_site is tested in spec/models/concerns/site_scoped_spec.rb
  end

  describe "scopes" do
    let(:site) { create(:site) }

    describe ".roots" do
      it "returns taxonomies without parent" do
        root1 = create(:taxonomy, site: site, parent: nil)
        root2 = create(:taxonomy, site: site, parent: nil)
        child = create(:taxonomy, site: site, parent: root1)

        roots = Taxonomy.without_site_scope.where(site: site).roots
        expect(roots).to include(root1, root2)
        expect(roots).not_to include(child)
      end
    end

    describe ".by_position" do
      it "orders by position ascending" do
        tax3 = create(:taxonomy, site: site, position: 3)
        tax1 = create(:taxonomy, site: site, position: 1)
        tax2 = create(:taxonomy, site: site, position: 2)

        ordered = Taxonomy.without_site_scope.where(site: site).by_position
        expect(ordered.first).to eq(tax1)
        expect(ordered.second).to eq(tax2)
        expect(ordered.third).to eq(tax3)
      end
    end
  end

  describe "hierarchy methods" do
    let(:site) { create(:site) }
    let(:grandparent) { create(:taxonomy, site: site, name: "Grandparent") }
    let(:parent) { create(:taxonomy, site: site, name: "Parent", parent: grandparent) }
    let(:child) { create(:taxonomy, site: site, name: "Child", parent: parent) }
    let(:grandchild) { create(:taxonomy, site: site, name: "Grandchild", parent: child) }

    describe "#ancestors" do
      it "returns empty array for root taxonomy" do
        expect(grandparent.ancestors).to eq([])
      end

      it "returns parent for first-level child" do
        expect(parent.ancestors).to eq([ grandparent ])
      end

      it "returns all ancestors in order from root to immediate parent" do
        expect(grandchild.ancestors).to eq([ grandparent, parent, child ])
      end
    end

    describe "#descendants" do
      it "returns empty array for leaf taxonomy" do
        expect(grandchild.descendants).to eq([])
      end

      it "returns all descendants recursively" do
        # Force creation by referencing grandchild
        grandchild

        descendants = grandparent.descendants
        expect(descendants).to include(parent, child, grandchild)
        expect(descendants.size).to eq(3)
      end
    end

    describe "#full_path" do
      it "returns just name for root taxonomy" do
        expect(grandparent.full_path).to eq("Grandparent")
      end

      it "returns full path from root to current" do
        expect(grandchild.full_path).to eq("Grandparent / Parent / Child / Grandchild")
      end
    end

    describe "#root?" do
      it "returns true for root taxonomy" do
        expect(grandparent.root?).to be true
      end

      it "returns false for child taxonomy" do
        expect(child.root?).to be false
      end
    end
  end

  describe "site isolation" do
    let(:tenant) { create(:tenant) }
    let(:site1) { create(:site, tenant: tenant) }
    let(:site2) { create(:site, tenant: tenant) }

    it "allows same slug on different sites" do
      tax1 = create(:taxonomy, site: site1, slug: "tech")
      tax2 = build(:taxonomy, site: site2, slug: "tech")
      expect(tax2).to be_valid
    end

    it "prevents same slug on same site" do
      tax1 = create(:taxonomy, site: site1, slug: "tech")
      tax2 = build(:taxonomy, site: site1, slug: "tech")
      expect(tax2).not_to be_valid
      expect(tax2.errors[:slug]).to be_present
    end
  end
end
