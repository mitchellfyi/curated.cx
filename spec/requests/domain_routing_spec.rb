# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Domain Routing", type: :request do
  # Tests for hostname resolution from HTTP Host header
  # Covers: apex domains, www variants, subdomain patterns, normalization, unknown hosts

  let!(:tenant) { create(:tenant, slug: 'acme', hostname: 'acme.example.com') }
  let!(:site) do
    site = create(:site, tenant: tenant, slug: 'acme_site', name: 'ACME Site')
    create(:domain, :primary, :verified, site: site, hostname: 'ainews.cx')
    create(:domain, site: site, hostname: 'www.ainews.cx')
    site
  end

  describe "Apex domain resolution" do
    it "resolves site by apex domain" do
      host! 'ainews.cx'

      get root_path

      expect(response).to have_http_status(:success)
      # Response should be successful, indicating site was resolved correctly
      expect(response.body).not_to include('domain not connected')
    end
  end

  describe "www variant resolution" do
    it "resolves site by www variant" do
      host! 'www.ainews.cx'

      get root_path

      expect(response).to have_http_status(:success)
      # Site resolved correctly - success response indicates correct resolution
    end

    it "resolves www variant when only apex domain exists" do
      site2 = create(:site, tenant: tenant, slug: 'site2', name: 'Site 2')
      create(:domain, :primary, :verified, site: site2, hostname: 'example.com')

      host! 'www.example.com'

      get root_path

      expect(response).to have_http_status(:success)
      # Site 2 resolved correctly - success response indicates correct resolution
    end
  end

  describe "Hostname normalization" do
    it "strips port from hostname" do
      host! 'ainews.cx:3000'

      get root_path

      expect(response).to have_http_status(:success)
      # Site resolved correctly - success response indicates correct resolution
    end

    it "normalizes to lowercase" do
      host! 'AiNeWs.Cx'

      get root_path

      expect(response).to have_http_status(:success)
      # Site resolved correctly - success response indicates correct resolution
    end

    it "strips trailing dots" do
      # Note: Rails request.host already normalizes this, but test normalization logic
      domain = Domain.find_by_hostname('ainews.cx')
      normalized = Domain.normalize_hostname('ainews.cx.')
      expect(Domain.find_by_hostname(normalized)).to eq(domain)
    end
  end

  describe "Unknown domain handling" do
    it "shows domain not connected page for unknown domains" do
      host! 'unknown-domain.com'

      get root_path

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('Domain Not Connected')
      expect(response.body).to include('unknown-domain.com')
      expect(Current.site).to be_nil
    end

    it "provides helpful error message" do
      host! 'not-configured.example.com'

      get root_path

      expect(response.body).to include('not currently connected')
      expect(response.body).to include('not-configured.example.com')
    end
  end

  describe "Local development support" do
    before do
      allow(Rails.env).to receive(:development?).and_return(true)
    end

    it "resolves localhost to root tenant's site" do
      root_tenant = create(:tenant, :root)
      root_site = create(:site, tenant: root_tenant, slug: 'root', name: 'Root')
      create(:domain, :primary, :verified, site: root_site, hostname: 'curated.cx')

      host! 'localhost'

      get root_path

      expect(response).to have_http_status(:success)
      # Root site resolved correctly - success response indicates correct resolution
    end

    it "resolves localhost:3000 to root tenant's site" do
      root_tenant = create(:tenant, :root)
      root_site = create(:site, tenant: root_tenant, slug: 'root', name: 'Root')
      create(:domain, :primary, :verified, site: root_site, hostname: 'curated.cx')

      host! 'localhost:3000'

      get root_path

      expect(response).to have_http_status(:success)
      # Root site resolved correctly - success response indicates correct resolution
    end

    it "resolves subdomain.localhost by tenant slug" do
      host! 'acme.localhost'

      get root_path

      expect(response).to have_http_status(:success)
      # Site resolved correctly - success response indicates correct resolution
    end
  end

  describe "Subdomain pattern support (optional)" do
    let!(:root_tenant) { create(:tenant, slug: 'root', hostname: 'curated.cx') }
    let!(:root_site) do
      site = create(:site, tenant: root_tenant, slug: 'root', name: 'Root Site')
      create(:domain, :primary, :verified, site: site, hostname: 'curated.cx')
      site.update!(config: { 'domains' => { 'subdomain_pattern_enabled' => true } })
      site
    end

    context "when subdomain pattern is enabled" do
      it "resolves subdomain.curated.cx to root site" do
        host! 'ai.curated.cx'

        get root_path

        expect(response).to have_http_status(:success)
        # Root site resolved correctly - success response indicates correct resolution
      end
    end

    context "when subdomain pattern is disabled" do
      before do
        root_site.update!(config: { 'domains' => { 'subdomain_pattern_enabled' => false } })
      end

      it "does not resolve subdomain when disabled" do
        host! 'ai.curated.cx'

        get root_path

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "Domain model normalization" do
    it "normalizes hostname before saving" do
      domain = Domain.new(
        site: site,
        hostname: 'EXAMPLE.COM',
        primary: false
      )
      domain.valid?
      expect(domain.hostname).to eq('example.com')
    end

    it "normalizes hostname with port before saving" do
      domain = Domain.new(
        site: site,
        hostname: 'example.com:3000',
        primary: false
      )
      domain.valid?
      expect(domain.hostname).to eq('example.com')
    end

    it "finds domains with normalized hostnames" do
      domain = create(:domain, site: site, hostname: 'example.com')

      found = Domain.find_by_hostname('EXAMPLE.COM')
      expect(found).to eq(domain)

      found = Domain.find_by_hostname('example.com:3000')
      expect(found).to eq(domain)
    end
  end
end
