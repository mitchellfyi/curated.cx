# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantResolver do
  let(:app) { double('app') }
  let(:middleware) { described_class.new(app) }
  let(:env) { { 'HTTP_HOST' => hostname } }

  before do
    allow(app).to receive(:call).and_return([ 200, {}, [ 'OK' ] ])
    Current.reset!
  end

  describe '#call' do
    context 'with valid tenant hostname' do
      let(:hostname) { 'ainews.cx' }
      let(:tenant) { create(:tenant, hostname: 'ainews.cx', slug: 'ai') }
      let!(:site) { create(:site, tenant: tenant, slug: tenant.slug) }
      let!(:domain) { create(:domain, site: site, hostname: 'ainews.cx', primary: true) }

      it 'sets the current site and calls the app' do
        status, _, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.site).to eq(site)
        expect(Current.tenant).to eq(tenant)
        expect(app).to have_received(:call).with(env)
      end
    end

    context 'with hostname that has port' do
      let(:hostname) { 'ainews.cx:3000' }
      let(:tenant) { create(:tenant, hostname: 'ainews.cx', slug: 'ai') }
      let!(:site) { create(:site, tenant: tenant, slug: tenant.slug) }
      let!(:domain) { create(:domain, site: site, hostname: 'ainews.cx', primary: true) }

      it 'strips the port and resolves the site' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.site).to eq(site)
      end
    end

    context 'with unknown hostname' do
      let(:hostname) { 'unknown.example.com' }

      it 'redirects to domain not connected page' do
        middleware.call(env)

        expect(env['PATH_INFO']).to eq('/domain_not_connected')
        expect(env['X_DOMAIN_NOT_CONNECTED']).to eq('unknown.example.com')
        expect(app).to have_received(:call)
      end
    end

    context 'with disabled site' do
      let(:hostname) { 'disabled.example.com' }
      let(:tenant) { create(:tenant, hostname: 'disabled.example.com', slug: 'disabled', status: :disabled) }
      let!(:site) { create(:site, tenant: tenant, slug: tenant.slug, status: :disabled) }
      let!(:domain) { create(:domain, site: site, hostname: 'disabled.example.com', primary: true) }

      it 'redirects to domain not connected page' do
        middleware.call(env)

        expect(env['PATH_INFO']).to eq('/domain_not_connected')
        expect(env['X_DOMAIN_NOT_CONNECTED']).to eq('disabled.example.com')
      end
    end

    context 'with private_access tenant' do
      let(:hostname) { 'private.example.com' }
      let(:tenant) { create(:tenant, hostname: 'private.example.com', slug: 'private', status: :private_access) }
      let!(:site) { create(:site, tenant: tenant, slug: tenant.slug, status: :private_access) }
      let!(:domain) { create(:domain, site: site, hostname: 'private.example.com', primary: true) }

      it 'allows access to private_access sites' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.site).to eq(site)
      end
    end

    context 'with health check endpoint' do
      let(:hostname) { 'ainews.cx' }
      let(:env) { { 'HTTP_HOST' => hostname, 'PATH_INFO' => '/up' } }

      it 'skips site resolution' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.site).to be_nil
        expect(app).to have_received(:call).with(env)
      end
    end

    context 'with localhost in development' do
      let(:hostname) { 'localhost' }
      let(:root_tenant) { create(:tenant, hostname: 'curated.cx', slug: 'root') }
      let!(:root_site) { create(:site, tenant: root_tenant, slug: root_tenant.slug) }
      let!(:root_domain) { create(:domain, site: root_site, hostname: 'curated.cx', primary: true) }

      before do
        allow(Tenant).to receive(:root_tenant).and_return(root_tenant)
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'resolves to root tenant site' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.tenant).to eq(root_tenant)
      end
    end

    context 'with subdomain in development' do
      let(:hostname) { 'ai.localhost' }
      let(:tenant) { create(:tenant, hostname: 'ainews.cx', slug: 'ai') }
      let(:root_tenant) { create(:tenant, hostname: 'curated.cx', slug: 'root') }
      let!(:site) { create(:site, tenant: tenant, slug: tenant.slug) }
      let!(:domain) { create(:domain, site: site, hostname: 'ainews.cx', primary: true) }

      before do
        allow(Tenant).to receive(:root_tenant).and_return(root_tenant)
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'resolves site by subdomain slug' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.site).to eq(site)
      end
    end

    context 'with missing HTTP_HOST' do
      let(:env) { {} }

      it 'handles gracefully by redirecting to domain not connected' do
        middleware.call(env)

        expect(env['PATH_INFO']).to eq('/domain_not_connected')
      end
    end

    context 'when database error occurs' do
      let(:hostname) { 'test.example.com' }

      before do
        allow(Domain).to receive(:find_by_hostname).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      end

      it 'handles the error gracefully by redirecting' do
        middleware.call(env)

        expect(env['PATH_INFO']).to eq('/domain_not_connected')
      end
    end
  end
end
