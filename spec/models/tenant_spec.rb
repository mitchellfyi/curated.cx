# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tenant, type: :model do
  describe 'associations' do
    it { should have_many(:categories).dependent(:destroy) }
    it { should have_many(:listings).dependent(:destroy) }
  end

  describe 'validations' do
    subject { create(:tenant) }

    it { should validate_presence_of(:hostname) }
    it { should validate_uniqueness_of(:hostname) }
    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
    it { should validate_presence_of(:title) }
    it { should validate_length_of(:title).is_at_least(1).is_at_most(255) }
    it { should validate_length_of(:description).is_at_most(1000) }
    it { should validate_presence_of(:status) }
    it { should allow_value('').for(:description) }
    it { should allow_value(nil).for(:description) }
    it { should allow_value('').for(:logo_url) }
    it { should allow_value(nil).for(:logo_url) }

    describe 'hostname validation' do
      it 'allows valid domain names' do
        valid_hostnames = [
          'example.com',
          'subdomain.example.com',
          'test-site.com',
          'site123.co.uk',
          'a.b.c.d.com'
        ]

        valid_hostnames.each do |hostname|
          tenant = build(:tenant, hostname: hostname)
          expect(tenant).to be_valid, "#{hostname} should be valid"
        end
      end

      it 'rejects invalid domain names' do
        invalid_hostnames = [
          '',
          'invalid_hostname',
          'hostname with spaces',
          '-invalid.com',
          'invalid-.com'
        ]

        invalid_hostnames.each do |hostname|
          tenant = build(:tenant, hostname: hostname)
          expect(tenant).not_to be_valid, "#{hostname} should be invalid"
          expect(tenant.errors[:hostname]).to include('must be a valid domain name')
        end
      end
    end

    describe 'slug validation' do
      it 'allows valid slugs' do
        valid_slugs = %w[test test123 test_slug root admin_panel]

        valid_slugs.each do |slug|
          tenant = build(:tenant, slug: slug)
          expect(tenant).to be_valid, "#{slug} should be valid"
        end
      end

      it 'rejects invalid slugs' do
        invalid_slugs = [
          '',
          'invalid-slug',
          'invalid slug',
          'Test',
          'UPPERCASE',
          'slug with spaces',
          'slug@email.com'
        ]

        invalid_slugs.each do |slug|
          tenant = build(:tenant, slug: slug)
          expect(tenant).not_to be_valid, "#{slug} should be invalid"
          expect(tenant.errors[:slug]).to include('must contain only lowercase letters, numbers, and underscores')
        end
      end
    end

    describe 'logo_url validation' do
      it 'allows valid URLs' do
        valid_urls = [
          'https://example.com/logo.png',
          'http://example.com/logo.jpg',
          'https://cdn.example.com/path/to/logo.svg'
        ]

        valid_urls.each do |url|
          tenant = build(:tenant, logo_url: url)
          expect(tenant).to be_valid, "#{url} should be valid"
        end
      end

      it 'rejects invalid URLs' do
        invalid_urls = [
          'not-a-url',
          'ftp://example.com/logo.png',
          'javascript:alert("xss")',
          'relative/path/logo.png'
        ]

        invalid_urls.each do |url|
          tenant = build(:tenant, logo_url: url)
          expect(tenant).not_to be_valid, "#{url} should be invalid"
          expect(tenant.errors[:logo_url]).to include('must be a valid URL')
        end
      end
    end

    describe 'settings validation' do
      it 'allows empty settings' do
        tenant = build(:tenant, settings: {})
        expect(tenant).to be_valid
      end

      it 'allows nil settings' do
        tenant = build(:tenant, settings: nil)
        expect(tenant).to be_valid
      end

      it 'rejects non-hash settings' do
        tenant = build(:tenant, settings: 'invalid')
        expect(tenant).not_to be_valid
        expect(tenant.errors[:settings]).to include('must be a valid JSON object')
      end

      describe 'theme validation' do
        it 'allows valid theme colors' do
          valid_colors = %w[blue gray red yellow green indigo purple pink amber]

          valid_colors.each do |color|
            settings = { 'theme' => { 'primary_color' => color, 'secondary_color' => color } }
            tenant = build(:tenant, settings: settings)
            expect(tenant).to be_valid, "#{color} should be valid"
          end
        end

        it 'rejects invalid theme colors' do
          invalid_colors = %w[orange black white lime teal cyan rose]

          invalid_colors.each do |color|
            settings = { 'theme' => { 'primary_color' => color } }
            tenant = build(:tenant, settings: settings)
            expect(tenant).not_to be_valid, "#{color} should be invalid"
            expect(tenant.errors[:settings]).to include('primary_color must be a valid Tailwind color')
          end
        end

        it 'rejects non-hash theme' do
          settings = { 'theme' => 'invalid' }
          tenant = build(:tenant, settings: settings)
          expect(tenant).not_to be_valid
          expect(tenant.errors[:settings]).to include('theme must be a valid object')
        end
      end

      describe 'categories validation' do
        it 'allows valid categories configuration' do
          settings = {
            'categories' => {
              'news' => { 'enabled' => true },
              'apps' => { 'enabled' => false }
            }
          }
          tenant = build(:tenant, settings: settings)
          expect(tenant).to be_valid
        end

        it 'rejects categories without enabled property' do
          settings = {
            'categories' => {
              'news' => { 'other_property' => true }
            }
          }
          tenant = build(:tenant, settings: settings)
          expect(tenant).not_to be_valid
          expect(tenant.errors[:settings]).to include("category 'news' must have an 'enabled' property")
        end

        it 'rejects non-hash categories' do
          settings = { 'categories' => 'invalid' }
          tenant = build(:tenant, settings: settings)
          expect(tenant).not_to be_valid
          expect(tenant.errors[:settings]).to include('categories must be a valid object')
        end
      end
    end
  end

  describe 'enums' do
    it 'defines status enum correctly' do
      expect(Tenant.statuses).to eq({
        'enabled' => 0,
        'disabled' => 1,
        'private_access' => 2
      })
    end

    it 'allows setting status' do
      tenant = create(:tenant)

      tenant.enabled!
      expect(tenant).to be_enabled

      tenant.disabled!
      expect(tenant).to be_disabled

      tenant.private_access!
      expect(tenant).to be_private_access
    end
  end

  describe 'scopes' do
    let!(:enabled_tenant) { create(:tenant, :enabled) }
    let!(:disabled_tenant) { create(:tenant, :disabled) }
    let!(:private_tenant) { create(:tenant, :private_access) }

    describe '.active' do
      it 'returns only enabled tenants' do
        expect(Tenant.active).to contain_exactly(enabled_tenant)
      end
    end

    describe '.by_hostname' do
      it 'finds tenant by hostname' do
        expect(Tenant.by_hostname(enabled_tenant.hostname)).to contain_exactly(enabled_tenant)
      end

      it 'returns empty when hostname not found' do
        expect(Tenant.by_hostname('nonexistent.com')).to be_empty
      end
    end
  end

  describe 'callbacks' do
    describe 'cache clearing' do
      let(:tenant) { create(:tenant, hostname: 'test.com') }

      it 'clears cache on save' do
        expect(Rails.cache).to receive(:delete).with("tenant:hostname:#{tenant.hostname}")
        expect(Rails.cache).to receive(:delete_matched).with('tenant:*')
        tenant.update!(title: 'New Title')
      end

      it 'clears cache on destroy' do
        expect(Rails.cache).to receive(:delete).with("tenant:hostname:#{tenant.hostname}")
        expect(Rails.cache).to receive(:delete_matched).with('tenant:*')
        tenant.destroy!
      end

      it 'clears root cache when tenant is root' do
        root_tenant = create(:tenant, slug: 'root')
        expect(Rails.cache).to receive(:delete).with("tenant:hostname:#{root_tenant.hostname}")
        expect(Rails.cache).to receive(:delete).with('tenant:root')
        expect(Rails.cache).to receive(:delete_matched).with('tenant:*')
        root_tenant.update!(title: 'New Title')
      end
    end
  end

  describe 'class methods' do
    describe '.find_by_hostname!' do
      let!(:tenant) { create(:tenant, hostname: 'example.com') }

      it 'finds tenant by hostname with caching' do
        expect(Rails.cache).to receive(:fetch)
          .with("tenant:hostname:example.com", expires_in: 1.hour)
          .and_call_original

        result = Tenant.find_by_hostname!('example.com')
        expect(result).to eq(tenant)
      end

      it 'raises error when tenant not found' do
        expect {
          Tenant.find_by_hostname!('nonexistent.com')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe '.root_tenant' do
      let!(:root_tenant) { create(:tenant, slug: 'root') }

      it 'finds root tenant with caching' do
        expect(Rails.cache).to receive(:fetch)
          .with('tenant:root', expires_in: 1.hour)
          .and_call_original

        result = Tenant.root_tenant
        expect(result).to eq(root_tenant)
      end

      it 'raises error when root tenant not found' do
        root_tenant.destroy
        expect {
          Tenant.root_tenant
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe '.clear_cache!' do
      it 'clears all tenant cache entries' do
        expect(Rails.cache).to receive(:delete_matched).with('tenant:*')
        Tenant.clear_cache!
      end
    end
  end

  describe 'instance methods' do
    let(:tenant) { create(:tenant, slug: 'test') }
    let(:root_tenant) { create(:tenant, slug: 'root') }

    describe '#root?' do
      it 'returns true for root tenant' do
        expect(root_tenant).to be_root
      end

      it 'returns false for non-root tenant' do
        expect(tenant).not_to be_root
      end
    end

    describe '#settings' do
      it 'returns empty hash when settings is empty' do
        tenant.update!(settings: {})
        expect(tenant.settings).to eq({})
      end

      it 'returns actual settings when present' do
        settings = { 'test' => 'value' }
        tenant.update!(settings: settings)
        expect(tenant.settings).to eq(settings)
      end
    end

    describe '#setting' do
      before do
        tenant.update!(settings: {
          'simple_key' => 'simple_value',
          'nested' => {
            'key' => 'nested_value',
            'deeper' => {
              'key' => 'deep_value'
            }
          }
        })
      end

      it 'retrieves simple setting' do
        expect(tenant.setting('simple_key')).to eq('simple_value')
      end

      it 'retrieves nested setting with dot notation' do
        expect(tenant.setting('nested.key')).to eq('nested_value')
      end

      it 'retrieves deeply nested setting' do
        expect(tenant.setting('nested.deeper.key')).to eq('deep_value')
      end

      it 'returns default value when key not found' do
        expect(tenant.setting('nonexistent', 'default')).to eq('default')
      end

      it 'returns nil when key not found and no default' do
        expect(tenant.setting('nonexistent')).to be_nil
      end

      it 'handles symbol keys' do
        expect(tenant.setting(:simple_key)).to eq('simple_value')
      end
    end

    describe '#update_setting' do
      it 'updates simple setting' do
        tenant.update_setting('new_key', 'new_value')
        expect(tenant.setting('new_key')).to eq('new_value')
      end

      it 'updates nested setting' do
        tenant.update_setting('nested.new_key', 'new_value')
        expect(tenant.setting('nested.new_key')).to eq('new_value')
      end

      it 'creates nested structure if not present' do
        tenant.update_setting('deep.nested.key', 'value')
        expect(tenant.setting('deep.nested.key')).to eq('value')
      end

      it 'preserves existing settings' do
        tenant.update!(settings: { 'existing' => 'value' })
        tenant.update_setting('new_key', 'new_value')

        expect(tenant.setting('existing')).to eq('value')
        expect(tenant.setting('new_key')).to eq('new_value')
      end

      it 'persists changes to database' do
        tenant.update_setting('test_key', 'test_value')
        tenant.reload
        expect(tenant.setting('test_key')).to eq('test_value')
      end
    end

    describe '#category_enabled?' do
      before do
        tenant.update!(settings: {
          'categories' => {
            'news' => { 'enabled' => true },
            'apps' => { 'enabled' => false }
          }
        })
      end

      it 'returns true for enabled category' do
        expect(tenant.category_enabled?('news')).to be true
      end

      it 'returns false for disabled category' do
        expect(tenant.category_enabled?('apps')).to be false
      end

      it 'returns false for non-existent category' do
        expect(tenant.category_enabled?('services')).to be false
      end
    end

    describe '#enabled_categories' do
      before do
        tenant.update!(settings: {
          'categories' => {
            'news' => { 'enabled' => true },
            'apps' => { 'enabled' => false },
            'services' => { 'enabled' => true }
          }
        })
      end

      it 'returns only enabled categories' do
        expect(tenant.enabled_categories).to contain_exactly('news', 'services')
      end

      it 'returns empty array when no categories enabled' do
        tenant.update!(settings: {})
        expect(tenant.enabled_categories).to be_empty
      end
    end

    describe 'theme helpers' do
      describe '#primary_color' do
        it 'returns configured primary color' do
          tenant.update!(settings: { 'theme' => { 'primary_color' => 'red' } })
          expect(tenant.primary_color).to eq('red')
        end

        it 'returns default when not configured' do
          expect(tenant.primary_color).to eq('blue')
        end
      end

      describe '#secondary_color' do
        it 'returns configured secondary color' do
          tenant.update!(settings: { 'theme' => { 'secondary_color' => 'green' } })
          expect(tenant.secondary_color).to eq('green')
        end

        it 'returns default when not configured' do
          expect(tenant.secondary_color).to eq('gray')
        end
      end
    end

    describe 'status helpers' do
      describe '#publicly_accessible?' do
        it 'returns true for enabled tenant' do
          tenant.enabled!
          expect(tenant).to be_publicly_accessible
        end

        it 'returns false for disabled tenant' do
          tenant.disabled!
          expect(tenant).not_to be_publicly_accessible
        end

        it 'returns false for private access tenant' do
          tenant.private_access!
          expect(tenant).not_to be_publicly_accessible
        end
      end

      describe '#requires_login?' do
        it 'returns true for private access tenant' do
          tenant.private_access!
          expect(tenant.requires_login?).to be true
        end

        it 'returns false for enabled tenant' do
          tenant.enabled!
          expect(tenant.requires_login?).to be false
        end

        it 'returns false for disabled tenant' do
          tenant.disabled!
          expect(tenant.requires_login?).to be false
        end
      end
    end
  end

  describe 'factory' do
    it 'creates valid tenant with factory' do
      tenant = build(:tenant)
      expect(tenant).to be_valid
    end

    it 'creates enabled tenant with trait' do
      tenant = create(:tenant, :enabled)
      expect(tenant).to be_enabled
    end

    it 'creates disabled tenant with trait' do
      tenant = create(:tenant, :disabled)
      expect(tenant).to be_disabled
    end

    it 'creates private access tenant with trait' do
      tenant = create(:tenant, :private_access)
      expect(tenant).to be_private_access
    end
  end
end