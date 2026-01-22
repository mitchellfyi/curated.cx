# frozen_string_literal: true

# == Schema Information
#
# Table name: sites
#
#  id          :bigint           not null, primary key
#  config      :jsonb            not null
#  description :text
#  name        :string           not null
#  slug        :string           not null
#  status      :integer          default("enabled"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_sites_on_status                (status)
#  index_sites_on_tenant_id             (tenant_id)
#  index_sites_on_tenant_id_and_slug    (tenant_id,slug) UNIQUE
#  index_sites_on_tenant_id_and_status  (tenant_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (tenant_id => tenants.id)
#
require 'rails_helper'

RSpec.describe Site, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:tenant) }
    it { is_expected.to have_many(:domains).dependent(:destroy) }
    it { is_expected.to have_one(:primary_domain).conditions(primary: true).class_name('Domain') }
  end

  describe 'validations' do
    let(:tenant) { create(:tenant) }

    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_length_of(:name).is_at_least(1).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1000) }

    it 'validates uniqueness of slug scoped to tenant' do
      create(:site, tenant: tenant, slug: 'unique_slug')
      duplicate = build(:site, tenant: tenant, slug: 'unique_slug')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to include('has already been taken')
    end

    it 'allows same slug for different tenants' do
      tenant1 = create(:tenant)
      tenant2 = create(:tenant)
      create(:site, tenant: tenant1, slug: 'same_slug')
      site2 = build(:site, tenant: tenant2, slug: 'same_slug')
      expect(site2).to be_valid
    end

    it 'validates slug format' do
      site = build(:site, slug: 'invalid-slug!')
      expect(site).not_to be_valid
      expect(site.errors[:slug]).to be_present
    end

    it 'validates config structure' do
      site = build(:site, config: 'invalid')
      expect(site).not_to be_valid
      expect(site.errors[:config]).to include('must be a valid JSON object')
    end

    it 'validates topics in config' do
      site = build(:site, config: { topics: 'not-an-array' })
      expect(site).not_to be_valid
      expect(site.errors[:config]).to include('topics must be an array')
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(enabled: 0, disabled: 1, private_access: 2) }
  end

  describe 'scopes' do
    let(:tenant) { create(:tenant) }
    let!(:enabled_site) { create(:site, tenant: tenant, status: :enabled) }
    let!(:disabled_site) { create(:site, tenant: tenant, status: :disabled) }

    describe '.active' do
      it 'returns only enabled sites' do
        expect(described_class.active).to include(enabled_site)
        expect(described_class.active).not_to include(disabled_site)
      end
    end

    describe '.by_tenant' do
      let(:other_tenant) { create(:tenant) }
      let!(:other_site) { create(:site, tenant: other_tenant) }

      it 'returns sites for the specified tenant' do
        expect(described_class.by_tenant(tenant)).to include(enabled_site, disabled_site)
        expect(described_class.by_tenant(tenant)).not_to include(other_site)
      end
    end
  end

  describe 'class methods' do
    describe '.find_by_hostname!' do
      let(:site) { create(:site) }
      let(:domain) { create(:domain, :primary, site: site, hostname: 'example.com') }

      before { domain }

      it 'finds site by domain hostname' do
        expect(described_class.find_by_hostname!('example.com')).to eq(site)
      end

      it 'raises error for unknown hostname' do
        expect {
          described_class.find_by_hostname!('unknown.com')
        }.to raise_error(ActiveRecord::RecordNotFound, /Site not found for hostname: unknown.com/)
      end
    end
  end

  describe 'instance methods' do
    describe '#config' do
      it 'returns empty hash when config is nil' do
        site = build(:site, config: nil)
        expect(site.config).to eq({})
      end

      it 'returns config hash when present' do
        config = { 'topics' => [ 'tech' ] }
        site = build(:site, config: config)
        expect(site.config).to eq(config)
      end
    end

    describe '#setting' do
      let(:site) do
        site = create(:site)
        site.update!(config: {
          'topics' => [ 'tech', 'business' ],
          'ingestion' => { 'enabled' => true },
          'monetisation' => { 'enabled' => false }
        })
        site.reload
      end

      it 'returns nested setting value' do
        expect(site.setting('ingestion.enabled')).to be true
        expect(site.setting('monetisation.enabled')).to be false
      end

      it 'returns default when setting not found' do
        expect(site.setting('nonexistent.setting', 'default')).to eq('default')
      end

      it 'returns nil when setting not found and no default' do
        expect(site.setting('nonexistent.setting')).to be_nil
      end
    end

    describe '#update_setting' do
      let(:site) { create(:site, config: { topics: [ 'tech' ] }) }

      it 'updates nested setting' do
        site.update_setting('ingestion.enabled', true)
        expect(site.reload.setting('ingestion.enabled')).to be true
      end

      it 'preserves existing settings' do
        site.update_setting('ingestion.enabled', true)
        expect(site.reload.setting('topics')).to eq([ 'tech' ])
      end
    end

    describe '#topics' do
      it 'returns topics from config' do
        site = create(:site, config: { 'topics' => [ 'tech', 'business' ] })
        expect(site.topics).to eq([ 'tech', 'business' ])
      end

      it 'returns empty array when topics not set' do
        site = create(:site, config: {})
        expect(site.topics).to eq([])
      end
    end

    describe '#ingestion_sources_enabled?' do
      it 'returns true when enabled in config' do
        site = create(:site, config: { ingestion: { enabled: true } })
        expect(site.ingestion_sources_enabled?).to be true
      end

      it 'returns false when disabled in config' do
        site = create(:site)
        site.update!(config: { 'ingestion' => { 'enabled' => false } })
        site.reload
        expect(site.ingestion_sources_enabled?).to be false
      end

      it 'returns true by default' do
        site = create(:site, config: {})
        expect(site.ingestion_sources_enabled?).to be true
      end
    end

    describe '#monetisation_enabled?' do
      it 'returns true when enabled in config' do
        site = create(:site, config: { 'monetisation' => { 'enabled' => true } })
        expect(site.monetisation_enabled?).to be true
      end

      it 'returns false by default' do
        site = create(:site, config: {})
        expect(site.monetisation_enabled?).to be false
      end
    end

    describe '#publicly_accessible?' do
      it 'returns true for enabled sites' do
        site = create(:site, status: :enabled)
        expect(site.publicly_accessible?).to be true
      end

      it 'returns false for disabled sites' do
        site = create(:site, status: :disabled)
        expect(site.publicly_accessible?).to be false
      end
    end

    describe '#requires_login?' do
      it 'returns true for private_access sites' do
        site = create(:site, status: :private_access)
        expect(site.requires_login?).to be true
      end

      it 'returns false for enabled sites' do
        site = create(:site, status: :enabled)
        expect(site.requires_login?).to be false
      end
    end

    describe '#primary_hostname' do
      it 'returns hostname of primary domain' do
        site = create(:site)
        domain = create(:domain, :primary, site: site, hostname: 'example.com')
        expect(site.primary_hostname).to eq('example.com')
      end

      it 'returns nil when no primary domain' do
        site = create(:site)
        expect(site.primary_hostname).to be_nil
      end
    end

    describe '#verified_domains' do
      it 'returns only verified domains' do
        site = create(:site)
        verified = create(:domain, :verified, site: site)
        unverified = create(:domain, site: site)
        expect(site.verified_domains).to include(verified)
        expect(site.verified_domains).not_to include(unverified)
      end
    end
  end

  describe 'callbacks' do
    describe 'after_save :clear_site_cache' do
      let(:site) { create(:site) }
      let(:domain) { create(:domain, site: site, hostname: 'example.com') }

      before do
        Rails.cache.write("site:hostname:#{domain.hostname}", site)
      end

      it 'clears cache when site is updated' do
        site.update!(name: 'New Name')
        expect(Rails.cache.read("site:hostname:#{domain.hostname}")).to be_nil
      end
    end
  end
end
