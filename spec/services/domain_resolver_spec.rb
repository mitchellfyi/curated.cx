# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DomainResolver do
  let(:tenant) { create(:tenant, hostname: 'example.com', slug: 'example') }
  let(:site) { create(:site, tenant: tenant, slug: tenant.slug) }
  let(:domain) { create(:domain, site: site, hostname: 'example.com', primary: true) }

  describe '.resolve' do
    it 'delegates to instance resolve' do
      domain # create the domain

      result = described_class.resolve('example.com')

      expect(result).to eq(site)
    end
  end

  describe '#initialize' do
    it 'normalizes hostname to lowercase' do
      resolver = described_class.new('EXAMPLE.COM')

      expect(resolver.hostname).to eq('example.com')
    end

    it 'strips port from hostname' do
      resolver = described_class.new('example.com:3000')

      expect(resolver.hostname).to eq('example.com')
    end

    it 'strips trailing dots from hostname' do
      resolver = described_class.new('example.com.')

      expect(resolver.hostname).to eq('example.com')
    end

    it 'handles nil hostname' do
      resolver = described_class.new(nil)

      expect(resolver.hostname).to be_nil
    end

    it 'handles blank hostname' do
      resolver = described_class.new('')

      expect(resolver.hostname).to be_nil
    end
  end

  describe '#resolve' do
    context 'with blank hostname' do
      it 'returns nil for nil hostname' do
        resolver = described_class.new(nil)

        expect(resolver.resolve).to be_nil
      end

      it 'returns nil for empty hostname' do
        resolver = described_class.new('')

        expect(resolver.resolve).to be_nil
      end
    end

    context 'exact domain match' do
      it 'returns site for exact hostname match' do
        domain # create the domain

        resolver = described_class.new('example.com')

        expect(resolver.resolve).to eq(site)
      end

      it 'returns site for hostname with port' do
        domain # create the domain

        resolver = described_class.new('example.com:3000')

        expect(resolver.resolve).to eq(site)
      end

      it 'returns site for uppercase hostname' do
        domain # create the domain

        resolver = described_class.new('EXAMPLE.COM')

        expect(resolver.resolve).to eq(site)
      end

      it 'returns nil for unknown hostname' do
        resolver = described_class.new('unknown.com')

        expect(resolver.resolve).to be_nil
      end
    end

    context 'disabled site filtering' do
      let(:disabled_tenant) { create(:tenant, hostname: 'disabled.com', slug: 'disabled', status: :disabled) }
      let(:disabled_site) { create(:site, tenant: disabled_tenant, slug: disabled_tenant.slug, status: :disabled) }
      let!(:disabled_domain) { create(:domain, site: disabled_site, hostname: 'disabled.com', primary: true) }

      it 'returns nil for disabled site' do
        resolver = described_class.new('disabled.com')

        expect(resolver.resolve).to be_nil
      end

      it 'returns site for private_access status' do
        private_tenant = create(:tenant, hostname: 'private.com', slug: 'private', status: :private_access)
        private_site = create(:site, tenant: private_tenant, slug: private_tenant.slug, status: :private_access)
        create(:domain, site: private_site, hostname: 'private.com', primary: true)

        resolver = described_class.new('private.com')

        expect(resolver.resolve).to eq(private_site)
      end
    end

    context 'www variant resolution (www → apex)' do
      it 'resolves www.example.com to apex domain' do
        domain # create apex domain (example.com)

        resolver = described_class.new('www.example.com')

        expect(resolver.resolve).to eq(site)
      end

      it 'returns nil when apex domain not found' do
        # No domain created

        resolver = described_class.new('www.unknown.com')

        expect(resolver.resolve).to be_nil
      end

      it 'returns nil when www domain is disabled' do
        disabled_tenant = create(:tenant, hostname: 'disabled.com', slug: 'disabled2', status: :disabled)
        disabled_site = create(:site, tenant: disabled_tenant, slug: disabled_tenant.slug, status: :disabled)
        create(:domain, site: disabled_site, hostname: 'disabled.com', primary: true)

        resolver = described_class.new('www.disabled.com')

        expect(resolver.resolve).to be_nil
      end
    end

    context 'apex variant resolution (apex → www)' do
      let(:www_domain) { create(:domain, site: site, hostname: 'www.example.com', primary: true) }

      it 'resolves apex to www domain when apex not found' do
        www_domain # create www domain but not apex

        resolver = described_class.new('example.com')

        expect(resolver.resolve).to eq(site)
      end

      it 'does not fallback to www when hostname starts with www' do
        # Create a domain for www.www.example.com (edge case)
        # The resolver should NOT look for www.www.example.com
        # when hostname is www.example.com
        www_domain # create www.example.com

        resolver = described_class.new('www.example.com')

        # Should try www → apex fallback (www.example.com → example.com), not apex → www
        # Since only www.example.com exists as domain, it should find it via exact match
        expect(resolver.resolve).to eq(site)
      end
    end

    context 'subdomain pattern resolution' do
      let(:apex_domain) { create(:domain, site: site, hostname: 'curated.cx', primary: true) }

      before do
        # Update domain hostname
        domain.update!(hostname: 'curated.cx')
        tenant.update!(hostname: 'curated.cx')
      end

      context 'when subdomain pattern is enabled' do
        before do
          # Enable subdomain pattern for the site
          site.update!(settings: { 'domains' => { 'subdomain_pattern_enabled' => true } })
        end

        it 'resolves ai.curated.cx to curated.cx domain' do
          resolver = described_class.new('ai.curated.cx')

          expect(resolver.resolve).to eq(site)
        end

        it 'resolves deeply nested subdomains' do
          resolver = described_class.new('blog.news.curated.cx')

          expect(resolver.resolve).to eq(site)
        end

        it 'returns nil when apex domain not found' do
          resolver = described_class.new('ai.unknown.com')

          expect(resolver.resolve).to be_nil
        end
      end

      context 'when subdomain pattern is disabled (default)' do
        it 'does not resolve subdomain to apex' do
          resolver = described_class.new('ai.curated.cx')

          # Should not resolve because subdomain_pattern_enabled is false by default
          expect(resolver.resolve).to be_nil
        end
      end

      context 'when site is disabled' do
        before do
          site.update!(
            status: :disabled,
            settings: { 'domains' => { 'subdomain_pattern_enabled' => true } }
          )
        end

        it 'returns nil even when subdomain pattern is enabled' do
          resolver = described_class.new('ai.curated.cx')

          expect(resolver.resolve).to be_nil
        end
      end
    end

    context 'legacy tenant fallback' do
      let(:legacy_tenant) { create(:tenant, hostname: 'legacy.example.com', slug: 'legacy') }
      let(:legacy_site) { create(:site, tenant: legacy_tenant, slug: legacy_tenant.slug) }

      it 'resolves by tenant hostname when no domain match' do
        legacy_site # create site for tenant

        resolver = described_class.new('legacy.example.com')

        expect(resolver.resolve).to eq(legacy_site)
      end

      it 'returns nil when tenant exists but has no matching site' do
        # Create tenant without a site that matches the slug
        orphan_tenant = create(:tenant, hostname: 'orphan.example.com', slug: 'orphan')
        # No site created

        resolver = described_class.new('orphan.example.com')

        expect(resolver.resolve).to be_nil
      end

      it 'returns nil when tenant is disabled' do
        disabled_tenant = create(:tenant, hostname: 'disabled-legacy.com', slug: 'disabled-legacy', status: :disabled)
        create(:site, tenant: disabled_tenant, slug: disabled_tenant.slug)

        resolver = described_class.new('disabled-legacy.com')

        expect(resolver.resolve).to be_nil
      end

      it 'returns nil when tenant hostname not found' do
        resolver = described_class.new('nonexistent.example.com')

        expect(resolver.resolve).to be_nil
      end
    end

    context 'resolution order (priority)' do
      let(:primary_domain) { create(:domain, site: site, hostname: 'primary.example.com', primary: true) }

      it 'prefers exact match over www variant' do
        # Create www domain pointing to a different site
        other_tenant = create(:tenant, hostname: 'other.com', slug: 'other')
        other_site = create(:site, tenant: other_tenant, slug: other_tenant.slug)
        create(:domain, site: other_site, hostname: 'www.primary.example.com', primary: true)
        primary_domain # exact match

        resolver = described_class.new('primary.example.com')

        # Should match exact, not fallback to www
        expect(resolver.resolve).to eq(site)
      end

      it 'prefers domain match over legacy tenant' do
        domain # domain match

        resolver = described_class.new('example.com')

        # Should match domain, not fall back to tenant
        expect(resolver.resolve).to eq(site)
      end
    end
  end

  describe 'private methods' do
    describe '#subdomain_pattern?' do
      let(:resolver) { described_class.new('test.com') }

      it 'returns true for 3+ part hostnames' do
        expect(resolver.send(:subdomain_pattern?, 'sub.example.com')).to be true
        expect(resolver.send(:subdomain_pattern?, 'a.b.c.example.com')).to be true
      end

      it 'returns false for 2 part hostnames' do
        expect(resolver.send(:subdomain_pattern?, 'example.com')).to be false
      end

      it 'returns false for blank hostname' do
        expect(resolver.send(:subdomain_pattern?, '')).to be false
        expect(resolver.send(:subdomain_pattern?, nil)).to be false
      end
    end

    describe '#extract_apex' do
      let(:resolver) { described_class.new('test.com') }

      it 'extracts apex from subdomain' do
        expect(resolver.send(:extract_apex, 'sub.example.com')).to eq('example.com')
        expect(resolver.send(:extract_apex, 'a.b.c.example.com')).to eq('b.c.example.com')
      end

      it 'returns nil for 2 part hostnames' do
        expect(resolver.send(:extract_apex, 'example.com')).to be_nil
      end
    end
  end
end
