# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id              :bigint           not null, primary key
#  hostname        :string           not null
#  last_checked_at :datetime
#  last_error      :text
#  primary         :boolean          default(FALSE), not null
#  status          :integer          default("pending_dns"), not null
#  verified        :boolean          default(FALSE), not null
#  verified_at     :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  site_id         :bigint           not null
#
# Indexes
#
#  index_domains_on_hostname               (hostname) UNIQUE
#  index_domains_on_site_id                (site_id)
#  index_domains_on_site_id_and_verified   (site_id,verified)
#  index_domains_on_site_id_where_primary  (site_id) UNIQUE WHERE ("primary" = true)
#  index_domains_on_status                 (status)
#
# Foreign Keys
#
#  fk_rails_...  (site_id => sites.id)
#
require 'rails_helper'

RSpec.describe Domain, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:site) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:hostname) }
    it 'validates uniqueness of hostname' do
      site = create(:site)
      create(:domain, site: site, hostname: 'example.com')
      duplicate = build(:domain, site: site, hostname: 'example.com')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:hostname]).to include('has already been taken')
    end

    it 'validates hostname format' do
      domain = build(:domain, hostname: 'invalid hostname!')
      expect(domain).not_to be_valid
      expect(domain.errors[:hostname]).to be_present
    end

    it 'allows valid hostnames' do
      expect(build(:domain, hostname: 'example.com')).to be_valid
      expect(build(:domain, hostname: 'www.example.com')).to be_valid
      expect(build(:domain, hostname: 'subdomain.example.com')).to be_valid
    end

    describe 'single primary domain per site' do
      let(:site) { create(:site) }
      let!(:primary_domain) { create(:domain, :primary, site: site) }

      it 'allows only one primary domain per site' do
        duplicate_primary = build(:domain, :primary, site: site)
        expect(duplicate_primary).not_to be_valid
        expect(duplicate_primary.errors[:primary]).to include('only one domain can be marked as primary per site')
      end

      it 'allows multiple non-primary domains' do
        expect(build(:domain, site: site, primary: false)).to be_valid
      end
    end
  end

  describe 'scopes' do
    let(:site) { create(:site) }
    let!(:primary_domain) { create(:domain, :primary, site: site) }
    let!(:secondary_domain) { create(:domain, site: site) }
    let!(:verified_domain) { create(:domain, :verified, site: site) }
    let!(:unverified_domain) { create(:domain, site: site) }

    describe '.primary' do
      it 'returns only primary domains' do
        expect(described_class.primary).to include(primary_domain)
        expect(described_class.primary).not_to include(secondary_domain)
      end
    end

    describe '.verified' do
      it 'returns only verified domains' do
        expect(described_class.verified).to include(verified_domain)
        expect(described_class.verified).not_to include(unverified_domain)
      end
    end

    describe '.unverified' do
      it 'returns only unverified domains' do
        expect(described_class.unverified).to include(unverified_domain)
        expect(described_class.unverified).not_to include(verified_domain)
      end
    end

    describe '.by_hostname' do
      it 'finds domain by hostname' do
        expect(described_class.by_hostname(primary_domain.hostname)).to include(primary_domain)
      end
    end
  end

  describe 'class methods' do
    describe '.find_by_hostname!' do
      let(:site) { create(:site) }
      let(:domain) { create(:domain, site: site, hostname: 'example.com') }

      before { domain }

      it 'finds domain by hostname' do
        expect(described_class.find_by_hostname!('example.com')).to eq(domain)
      end

      it 'raises error for unknown hostname' do
        expect {
          described_class.find_by_hostname!('unknown.com')
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'instance methods' do
    describe '#verify!' do
      let(:domain) { create(:domain, verified: false) }

      it 'marks domain as verified' do
        domain.verify!
        expect(domain.reload.verified).to be true
        expect(domain.verified_at).to be_present
      end
    end

    describe '#unverify!' do
      let(:domain) { create(:domain, :verified) }

      it 'marks domain as unverified' do
        domain.unverify!
        expect(domain.reload.verified).to be false
        expect(domain.verified_at).to be_nil
      end
    end

    describe '#make_primary!' do
      let(:site) { create(:site) }
      let!(:existing_primary) { create(:domain, :primary, site: site) }
      let(:new_primary) { create(:domain, site: site, primary: false) }

      it 'sets domain as primary and unsets others' do
        new_primary.make_primary!
        expect(new_primary.reload.primary).to be true
        expect(existing_primary.reload.primary).to be false
      end
    end
  end

  describe 'callbacks' do
    describe 'before_save :set_verified_at' do
      it 'sets verified_at when verifying' do
        domain = create(:domain, verified: false)
        domain.update!(verified: true)
        expect(domain.verified_at).to be_present
      end

      it 'clears verified_at when unverifying' do
        domain = create(:domain, :verified)
        domain.update!(verified: false)
        expect(domain.verified_at).to be_nil
      end
    end

    describe 'after_save :clear_domain_cache' do
      let(:domain) { create(:domain, hostname: 'example.com') }

      before do
        Rails.cache.write("site:hostname:#{domain.hostname}", domain.site)
      end

      it 'clears cache when domain is updated' do
        domain.update!(verified: true)
        expect(Rails.cache.read("site:hostname:#{domain.hostname}")).to be_nil
      end

      it 'clears scoped site cache entries for the associated site' do
        expect(Rails.cache).to receive(:delete_matched).with("site:#{domain.site_id}:*")
        domain.update!(verified: true)
      end
    end

    describe 'scoped cache invalidation' do
      # Use memory store to test actual cache behavior (test env uses null_store by default)
      around do |example|
        original_cache = Rails.cache
        Rails.cache = ActiveSupport::Cache::MemoryStore.new
        example.run
      ensure
        Rails.cache = original_cache
      end

      let(:tenant) { create(:tenant) }
      let(:site1) { create(:site, tenant: tenant) }
      let(:site2) { create(:site, tenant: tenant) }
      let!(:domain1) { create(:domain, site: site1, hostname: 'site1.example.com') }
      let!(:domain2) { create(:domain, site: site2, hostname: 'site2.example.com') }

      it 'only clears cache for the associated site, not other sites' do
        # Setup cache for both sites (simulating site-scoped data)
        Rails.cache.write("site:#{site1.id}:data", "site1_data")
        Rails.cache.write("site:#{site2.id}:data", "site2_data")

        # Update domain1 - triggers clear_domain_cache which clears site1's cache
        domain1.update!(verified: true)

        # Verify site1 cache cleared, site2 cache intact
        expect(Rails.cache.read("site:#{site1.id}:data")).to be_nil
        expect(Rails.cache.read("site:#{site2.id}:data")).to eq("site2_data")
      end
    end
  end

  describe 'defaults' do
    it 'defaults verified to false' do
      domain = described_class.new
      expect(domain.verified).to be false
    end

    it 'defaults primary to false' do
      domain = described_class.new
      expect(domain.primary).to be false
    end
  end

  describe '#apex_domain?' do
    let(:site) { create(:site) }

    it 'returns true for apex domains' do
      domain = build(:domain, site: site, hostname: 'example.com')
      expect(domain.apex_domain?).to be true
    end

    it 'returns false for subdomains' do
      domain = build(:domain, site: site, hostname: 'www.example.com')
      expect(domain.apex_domain?).to be false
    end

    it 'returns false for blank hostname' do
      domain = build(:domain, site: site, hostname: nil)
      expect(domain.apex_domain?(nil)).to be false
    end

    it 'can check a different hostname' do
      domain = build(:domain, site: site, hostname: 'example.com')
      expect(domain.apex_domain?('test.com')).to be true
      expect(domain.apex_domain?('sub.test.com')).to be false
    end
  end

  describe '#dns_target' do
    let(:site) { create(:site) }
    let(:domain) { create(:domain, site: site) }

    it 'returns default value when ENV not set' do
      allow(ENV).to receive(:fetch).with('DNS_TARGET', 'curated.cx').and_return('curated.cx')
      expect(domain.dns_target).to eq('curated.cx')
    end

    it 'returns ENV value when set' do
      allow(ENV).to receive(:fetch).with('DNS_TARGET', 'curated.cx').and_return('192.168.1.100')
      expect(domain.dns_target).to eq('192.168.1.100')
    end
  end
end
