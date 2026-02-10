# == Schema Information
#
# Table name: categories
#
#  id               :bigint           not null, primary key
#  allow_paths      :boolean          default(TRUE), not null
#  category_type    :string           default("article"), not null
#  display_template :string
#  key              :string           not null
#  metadata_schema  :jsonb            not null
#  name             :string           not null
#  shown_fields     :jsonb            not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  site_id          :bigint           not null
#  tenant_id        :bigint           not null
#
# Indexes
#
#  index_categories_on_site_id                    (site_id)
#  index_categories_on_site_id_and_category_type  (site_id,category_type)
#  index_categories_on_site_id_and_key            (site_id,key) UNIQUE
#  index_categories_on_site_id_and_name           (site_id,name)
#  index_categories_on_tenant_id                  (tenant_id)
#  index_categories_on_tenant_id_and_key          (tenant_id,key) UNIQUE
#  index_categories_on_tenant_name                (tenant_id,name)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
require 'rails_helper'

RSpec.describe Category, type: :model do
  let(:tenant) { create(:tenant) }

  describe 'associations' do
    it { should belong_to(:tenant) }
    it { should have_many(:entries).dependent(:destroy) }
  end

  describe 'validations' do
    let(:site) { create(:site, tenant: tenant) }
    subject { build(:category, site: site) }

    it { should validate_presence_of(:key) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:key).scoped_to(:site_id) }
    it { should validate_presence_of(:category_type) }

    it 'validates shown_fields is a hash' do
      category = build(:category, tenant: tenant, shown_fields: 'not a hash')
      expect(category).not_to be_valid
      expect(category.errors[:shown_fields]).to include('must be a valid JSON object')
    end

    it 'validates metadata_schema is a hash' do
      category = build(:category, tenant: tenant, metadata_schema: 'not a hash')
      expect(category).not_to be_valid
      expect(category.errors[:metadata_schema]).to include('must be a valid JSON object')
    end

    it 'validates category_type is included in CATEGORY_TYPES' do
      category = build(:category, tenant: tenant, category_type: 'invalid_type')
      expect(category).not_to be_valid
      expect(category.errors[:category_type]).to include('is not included in the list')
    end

    it 'accepts all valid category types' do
      Category::CATEGORY_TYPES.each do |type|
        category = build(:category, tenant: tenant, category_type: type)
        expect(category).to be_valid, "Expected category_type '#{type}' to be valid"
      end
    end
  end

  describe 'site isolation' do
    let(:tenant1) { create(:tenant, slug: 'tenant1') }
    let(:tenant2) { create(:tenant, slug: 'tenant2') }
    let(:site1) { create(:site, tenant: tenant1) }
    let(:site2) { create(:site, tenant: tenant2) }

    it 'allows same key across different sites' do
      ActsAsTenant.without_tenant do
        create(:category, site: site1, tenant: tenant1, key: 'news', name: 'News')
        expect { create(:category, site: site2, tenant: tenant2, key: 'news', name: 'News') }.not_to raise_error
      end
    end

    it 'prevents duplicate keys within same site' do
      ActsAsTenant.without_tenant do
        create(:category, site: site1, tenant: tenant1, key: 'news', name: 'News')
        expect { create(:category, site: site1, tenant: tenant1, key: 'news', name: 'Other News') }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#allows_url?' do
    context 'when allow_paths is true' do
      let(:category) { create(:category, tenant: tenant, allow_paths: true) }

      it 'allows root domain URLs' do
        expect(category.allows_url?('https://example.com')).to be true
        expect(category.allows_url?('https://example.com/')).to be true
      end

      it 'allows path URLs' do
        expect(category.allows_url?('https://example.com/article/123')).to be true
        expect(category.allows_url?('https://example.com/blog/post')).to be true
      end
    end

    context 'when allow_paths is false' do
      let(:category) { create(:category, tenant: tenant, allow_paths: false) }

      it 'allows root domain URLs' do
        expect(category.allows_url?('https://example.com')).to be true
        expect(category.allows_url?('https://example.com/')).to be true
      end

      it 'rejects path URLs' do
        expect(category.allows_url?('https://example.com/article/123')).to be false
        expect(category.allows_url?('https://example.com/blog/post')).to be false
      end
    end

    it 'handles invalid URLs gracefully' do
      category = create(:category, tenant: tenant, allow_paths: false) # Root domain only
      expect(category.allows_url?('not-a-url')).to be false
    end
  end

  describe 'scopes' do
    let!(:allowing_paths) { create(:category, tenant: tenant, allow_paths: true) }
    let!(:root_only) { create(:category, tenant: tenant, allow_paths: false) }

    it '.allowing_paths returns categories that allow paths' do
      ActsAsTenant.with_tenant(tenant) do
        expect(Category.allowing_paths).to include(allowing_paths)
        expect(Category.allowing_paths).not_to include(root_only)
      end
    end

    it '.root_domain_only returns categories that require root domain' do
      ActsAsTenant.with_tenant(tenant) do
        expect(Category.root_domain_only).to include(root_only)
        expect(Category.root_domain_only).not_to include(allowing_paths)
      end
    end
  end

  describe '#shown_fields' do
    it 'returns the actual hash when present' do
      fields = { 'title' => true, 'description' => false }
      category = create(:category, tenant: tenant, shown_fields: fields)
      expect(category.shown_fields).to eq(fields)
    end

    it 'returns empty hash as default from factory' do
      category = create(:category, tenant: tenant)
      expect(category.shown_fields).to be_a(Hash)
    end
  end

  describe '#category_type' do
    it 'defaults to article' do
      category = create(:category, tenant: tenant)
      expect(category.category_type).to eq('article')
    end

    it 'can be set to each valid type' do
      %w[article product service event job media discussion resource].each do |type|
        category = create(:category, tenant: tenant, category_type: type)
        expect(category.category_type).to eq(type)
      end
    end
  end

  describe '#effective_display_template' do
    it 'returns custom display_template when set' do
      category = create(:category, tenant: tenant, category_type: 'article', display_template: 'compact')
      expect(category.effective_display_template).to eq('compact')
    end

    it 'falls back to type default when display_template is nil' do
      category = create(:category, tenant: tenant, category_type: 'product')
      expect(category.effective_display_template).to eq('grid')
    end

    it 'falls back to type default when display_template is blank' do
      category = create(:category, tenant: tenant, category_type: 'event', display_template: '')
      expect(category.effective_display_template).to eq('calendar')
    end
  end

  describe '#type_icon' do
    it 'returns the correct icon for each type' do
      expect(create(:category, tenant: tenant, category_type: 'article').type_icon).to eq('📰')
      expect(create(:category, tenant: tenant, category_type: 'product').type_icon).to eq('📦')
      expect(create(:category, tenant: tenant, category_type: 'service').type_icon).to eq('🏢')
      expect(create(:category, tenant: tenant, category_type: 'event').type_icon).to eq('📅')
      expect(create(:category, tenant: tenant, category_type: 'job').type_icon).to eq('💼')
      expect(create(:category, tenant: tenant, category_type: 'media').type_icon).to eq('🎬')
      expect(create(:category, tenant: tenant, category_type: 'discussion').type_icon).to eq('💬')
      expect(create(:category, tenant: tenant, category_type: 'resource').type_icon).to eq('📚')
    end
  end

  describe '#metadata_schema' do
    it 'returns empty hash by default' do
      category = create(:category, tenant: tenant)
      expect(category.metadata_schema).to eq({})
    end

    it 'stores and retrieves custom metadata schema' do
      schema = { 'price' => 'number', 'currency' => 'string' }
      category = create(:category, tenant: tenant, metadata_schema: schema)
      expect(category.reload.metadata_schema).to eq(schema)
    end
  end

  describe '.by_type' do
    it 'filters categories by type' do
      article = create(:category, tenant: tenant, category_type: 'article')
      product = create(:category, tenant: tenant, category_type: 'product')

      ActsAsTenant.with_tenant(tenant) do
        expect(Category.by_type('article')).to include(article)
        expect(Category.by_type('article')).not_to include(product)
        expect(Category.by_type('product')).to include(product)
        expect(Category.by_type('product')).not_to include(article)
      end
    end
  end
end
