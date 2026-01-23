# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JsonbSettingsAccessor, type: :model do
  # Test using Site model which includes JsonbSettingsAccessor
  # Site uses :config as its jsonb_settings_column
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant, config: {}) }

  after do
    Current.reset
    ActsAsTenant.current_tenant = nil
  end

  describe '.jsonb_settings_column' do
    it 'is configurable per model' do
      expect(Site.jsonb_settings_column).to eq(:config)
      expect(Tenant.jsonb_settings_column).to eq(:settings)
    end
  end

  describe '#setting' do
    context 'with simple keys' do
      before { site.update!(config: { 'foo' => 'bar' }) }

      it 'retrieves a top-level value' do
        expect(site.setting('foo')).to eq('bar')
      end

      it 'works with symbol keys' do
        expect(site.setting(:foo)).to eq('bar')
      end
    end

    context 'with nested keys using dot notation' do
      before do
        site.update!(config: {
          'ingestion' => {
            'enabled' => true,
            'schedule' => 'daily'
          }
        })
      end

      it 'retrieves a nested value' do
        expect(site.setting('ingestion.enabled')).to eq(true)
        expect(site.setting('ingestion.schedule')).to eq('daily')
      end

      it 'works with symbol keys for nested access' do
        expect(site.setting(:'ingestion.enabled')).to eq(true)
      end
    end

    context 'with deeply nested keys' do
      before do
        site.update!(config: {
          'level1' => {
            'level2' => {
              'level3' => {
                'value' => 'deep'
              }
            }
          }
        })
      end

      it 'retrieves deeply nested values' do
        expect(site.setting('level1.level2.level3.value')).to eq('deep')
      end
    end

    context 'with default values' do
      it 'returns default when key is missing' do
        expect(site.setting('nonexistent', 'default_value')).to eq('default_value')
      end

      it 'returns nil when key is missing and no default provided' do
        expect(site.setting('nonexistent')).to be_nil
      end

      it 'returns default when nested path is missing' do
        expect(site.setting('missing.nested.key', 'fallback')).to eq('fallback')
      end
    end

    context 'with boolean false values' do
      before { site.update!(config: { 'feature_enabled' => false }) }

      it 'returns false, not the default' do
        expect(site.setting('feature_enabled', true)).to eq(false)
      end
    end

    context 'with empty config' do
      before { site.update!(config: {}) }

      it 'returns default when config is empty' do
        expect(site.setting('any.key', 'default')).to eq('default')
      end

      it 'returns nil when no default provided' do
        expect(site.setting('missing.key')).to be_nil
      end
    end

    context 'with array values' do
      before { site.update!(config: { 'topics' => %w[tech science art] }) }

      it 'retrieves array values correctly' do
        expect(site.setting('topics')).to eq(%w[tech science art])
      end
    end
  end

  describe '#update_setting' do
    context 'with simple keys' do
      it 'updates a top-level value' do
        site.update_setting('new_key', 'new_value')
        expect(site.reload.setting('new_key')).to eq('new_value')
      end

      it 'preserves existing settings' do
        site.update!(config: { 'existing' => 'value' })
        site.update_setting('new_key', 'new_value')
        expect(site.reload.setting('existing')).to eq('value')
        expect(site.setting('new_key')).to eq('new_value')
      end
    end

    context 'with nested keys' do
      it 'creates nested structure when it does not exist' do
        site.update_setting('nested.path.key', 'value')
        expect(site.reload.setting('nested.path.key')).to eq('value')
      end

      it 'preserves sibling keys when updating nested value' do
        site.update!(config: {
          'ingestion' => {
            'enabled' => true,
            'schedule' => 'daily'
          }
        })
        site.update_setting('ingestion.schedule', 'weekly')
        site.reload
        expect(site.setting('ingestion.enabled')).to eq(true)
        expect(site.setting('ingestion.schedule')).to eq('weekly')
      end
    end

    context 'with deeply nested keys' do
      it 'creates deep nested structure' do
        site.update_setting('a.b.c.d', 'deep_value')
        expect(site.reload.setting('a.b.c.d')).to eq('deep_value')
      end
    end

    context 'persisting to database' do
      it 'saves changes immediately' do
        site.update_setting('persisted', 'value')
        # Reload from database to verify persistence
        fresh_site = Site.find(site.id)
        expect(fresh_site.setting('persisted')).to eq('value')
      end

      it 'returns truthy on success' do
        result = site.update_setting('key', 'value')
        expect(result).to be_truthy
      end
    end

    context 'with different value types' do
      it 'handles integer values' do
        site.update_setting('count', 42)
        expect(site.reload.setting('count')).to eq(42)
      end

      it 'handles boolean values' do
        site.update_setting('enabled', false)
        expect(site.reload.setting('enabled')).to eq(false)
      end

      it 'handles array values' do
        site.update_setting('items', %w[a b c])
        expect(site.reload.setting('items')).to eq(%w[a b c])
      end

      it 'handles hash values' do
        site.update_setting('nested', { 'key' => 'value' })
        expect(site.reload.setting('nested')).to eq({ 'key' => 'value' })
      end

      it 'handles nil values' do
        site.update!(config: { 'to_remove' => 'exists' })
        site.update_setting('to_remove', nil)
        expect(site.reload.setting('to_remove')).to be_nil
      end
    end
  end

  describe 'integration with Tenant model' do
    let(:tenant_with_settings) do
      create(:tenant, settings: {
        'theme' => {
          'primary_color' => 'red',
          'secondary_color' => 'blue'
        },
        'categories' => {
          'tech' => { 'enabled' => true }
        }
      })
    end

    it 'retrieves settings from Tenant model' do
      expect(tenant_with_settings.setting('theme.primary_color')).to eq('red')
    end

    it 'updates settings on Tenant model' do
      tenant_with_settings.update_setting('theme.primary_color', 'green')
      expect(tenant_with_settings.reload.setting('theme.primary_color')).to eq('green')
    end

    it 'preserves existing settings when updating Tenant' do
      tenant_with_settings.update_setting('new_setting', 'value')
      tenant_with_settings.reload
      expect(tenant_with_settings.setting('theme.primary_color')).to eq('red')
      expect(tenant_with_settings.setting('categories.tech.enabled')).to eq(true)
      expect(tenant_with_settings.setting('new_setting')).to eq('value')
    end
  end
end
