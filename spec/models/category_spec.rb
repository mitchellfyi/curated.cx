# == Schema Information
#
# Table name: categories
#
#  id           :bigint           not null, primary key
#  allow_paths  :boolean          default(TRUE), not null
#  key          :string           not null
#  name         :string           not null
#  shown_fields :jsonb            not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  tenant_id    :bigint           not null
#
# Indexes
#
#  index_categories_on_tenant_id          (tenant_id)
#  index_categories_on_tenant_id_and_key  (tenant_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
require 'rails_helper'

RSpec.describe Category, type: :model do
  let(:tenant) { create(:tenant) }

  describe 'associations' do
    it { should belong_to(:tenant) }
    it { should have_many(:listings).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:category, tenant: tenant) }

    it { should validate_presence_of(:key) }
    it { should validate_presence_of(:name) }
    it { should validate_uniqueness_of(:key).scoped_to(:tenant_id) }
    it { should validate_inclusion_of(:allow_paths).in_array([ true, false ]) }

    it 'validates shown_fields is a hash' do
      category = build(:category, tenant: tenant, shown_fields: 'not a hash')
      expect(category).not_to be_valid
      expect(category.errors[:shown_fields]).to include('must be a valid JSON object')
    end
  end

  describe 'tenant isolation' do
    let(:tenant1) { create(:tenant, slug: 'tenant1') }
    let(:tenant2) { create(:tenant, slug: 'tenant2') }

    it 'allows same key across different tenants' do
      ActsAsTenant.with_tenant(tenant1) do
        create(:category, key: 'news', name: 'News')
      end

      ActsAsTenant.with_tenant(tenant2) do
        expect { create(:category, key: 'news', name: 'News') }.not_to raise_error
      end
    end

    it 'prevents duplicate keys within same tenant' do
      ActsAsTenant.with_tenant(tenant1) do
        create(:category, key: 'news', name: 'News')
        expect { create(:category, key: 'news', name: 'Other News') }.to raise_error(ActiveRecord::RecordInvalid)
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
end
