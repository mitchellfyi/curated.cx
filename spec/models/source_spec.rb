# frozen_string_literal: true

# == Schema Information
#
# Table name: sources
#
#  id          :bigint           not null, primary key
#  config      :jsonb            not null
#  enabled     :boolean          default(TRUE), not null
#  kind        :integer          not null
#  last_run_at :datetime
#  last_status :string
#  name        :string           not null
#  schedule    :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  site_id     :bigint           not null
#  tenant_id   :bigint           not null
#
# Indexes
#
#  index_sources_on_site_id                (site_id)
#  index_sources_on_site_id_and_name       (site_id,name) UNIQUE
#  index_sources_on_tenant_id              (tenant_id)
#  index_sources_on_tenant_id_and_enabled  (tenant_id,enabled)
#  index_sources_on_tenant_id_and_kind     (tenant_id,kind)
#  index_sources_on_tenant_id_and_name     (tenant_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
require 'rails_helper'

RSpec.describe Source, type: :model do
  let(:tenant) { create(:tenant) }
  let(:site) { create(:site, tenant: tenant) }

  describe 'associations' do
    it { should belong_to(:tenant) }
    it { should belong_to(:site) }
    it { should have_many(:listings).dependent(:nullify) }
  end

  describe 'validations' do
    subject { create(:source, site: site) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:kind) }
    it { should validate_uniqueness_of(:name).scoped_to(:site_id) }
    it { should validate_inclusion_of(:enabled).in_array([ true, false ]) }

    it 'validates config is a hash' do
      source = build(:source, site: site, config: 'not a hash')
      expect(source).not_to be_valid
      expect(source.errors[:config]).to include('must be a valid JSON object')
    end

    it 'validates schedule is a hash' do
      source = build(:source, site: site, schedule: 'not a hash')
      expect(source).not_to be_valid
      expect(source.errors[:schedule]).to include('must be a valid JSON object')
    end
  end

  describe 'enums' do
    it 'has correct kind values' do
      expect(Source.kinds.keys).to match_array(%w[serp_api_google_news rss api web_scraper])
    end
  end

  describe 'scopes' do
    let!(:enabled_source) { create(:source, site: site, enabled: true) }
    let!(:disabled_source) { create(:source, site: site, enabled: false) }
    let!(:rss_source) { create(:source, site: site, kind: :rss) }
    let!(:serp_source) { create(:source, site: site, kind: :serp_api_google_news) }

    describe '.enabled' do
      it 'returns only enabled sources' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Source.enabled).to include(enabled_source)
          expect(Source.enabled).not_to include(disabled_source)
        end
      end
    end

    describe '.disabled' do
      it 'returns only disabled sources' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Source.disabled).to include(disabled_source)
          expect(Source.disabled).not_to include(enabled_source)
        end
      end
    end

    describe '.by_kind' do
      it 'filters by kind' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Source.by_kind(:rss)).to include(rss_source)
          expect(Source.by_kind(:rss)).not_to include(serp_source)
        end
      end
    end

    describe '.due_for_run' do
      let!(:due_source) { create(:source, site: site, enabled: true, last_run_at: 2.hours.ago) }
      let!(:not_due_source) { create(:source, site: site, enabled: true, last_run_at: 10.minutes.ago) }

      it 'returns sources due for run' do
        ActsAsTenant.with_tenant(tenant) do
          expect(Source.due_for_run).to include(due_source)
          expect(Source.due_for_run).not_to include(not_due_source)
        end
      end
    end
  end

  describe '#config' do
    it 'returns empty hash by default' do
      source = create(:source, site: site, config: {})
      expect(source.config).to eq({})
    end

    it 'returns stored config' do
      config = { 'api_key' => 'test', 'query' => 'AI' }
      source = create(:source, site: site, config: config)
      expect(source.config).to eq(config)
    end
  end

  describe '#schedule' do
    it 'returns empty hash by default' do
      source = create(:source, site: site, schedule: {})
      expect(source.schedule).to eq({})
    end

    it 'returns stored schedule' do
      schedule = { 'interval_seconds' => 3600 }
      source = create(:source, site: site, schedule: schedule)
      expect(source.schedule).to eq(schedule)
    end
  end

  describe '#run_due?' do
    it 'returns true if never run' do
      source = create(:source, site: site, enabled: true, last_run_at: nil)
      expect(source.run_due?).to be true
    end

    it 'returns true if last run is older than interval' do
      source = create(:source, site: site, enabled: true, last_run_at: 2.hours.ago, schedule: { interval_seconds: 3600 })
      expect(source.run_due?).to be true
    end

    it 'returns false if recently run' do
      source = create(:source, site: site, enabled: true, last_run_at: 10.minutes.ago, schedule: { interval_seconds: 3600 })
      expect(source.run_due?).to be false
    end

    it 'returns false if disabled' do
      source = create(:source, site: site, enabled: false, last_run_at: 2.hours.ago, schedule: { interval_seconds: 3600 })
      expect(source.run_due?).to be false
    end
  end

  describe '#update_run_status' do
    it 'updates last_run_at and last_status' do
      source = create(:source, site: site)
      source.update_run_status('success')

      expect(source.last_run_at).to be_within(1.second).of(Time.current)
      expect(source.last_status).to eq('success')
    end
  end

  describe 'site isolation' do
    let(:tenant1) { create(:tenant, slug: 'tenant1') }
    let(:tenant2) { create(:tenant, slug: 'tenant2') }
    let(:site1) { create(:site, tenant: tenant1) }
    let(:site2) { create(:site, tenant: tenant2) }

    it 'allows same name across different sites' do
      create(:source, site: site1, name: 'My Source')
      expect { create(:source, site: site2, name: 'My Source') }.not_to raise_error
    end

    it 'prevents duplicate names within same site' do
      create(:source, site: site1, name: 'My Source')
      expect { create(:source, site: site1, name: 'My Source') }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
