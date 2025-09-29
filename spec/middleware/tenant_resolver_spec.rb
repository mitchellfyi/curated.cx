# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantResolver do
  let(:app) { double('app') }
  let(:middleware) { described_class.new(app) }
  let(:env) { { 'HTTP_HOST' => hostname } }

  before do
    allow(app).to receive(:call).and_return([ 200, {}, [ 'OK' ] ])
    Current.reset_tenant!
  end

  describe '#call' do
    context 'with valid tenant hostname' do
      let(:hostname) { 'ainews.cx' }
      let(:tenant) { create(:tenant, hostname: 'ainews.cx', slug: 'ai') }

      before { tenant }

      it 'sets the current tenant and calls the app' do
        status, _, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.tenant).to eq(tenant)
        expect(app).to have_received(:call).with(env)
      end
    end

    context 'with hostname that has port' do
      let(:hostname) { 'ainews.cx:3000' }
      let(:tenant) { create(:tenant, hostname: 'ainews.cx', slug: 'ai') }

      before { tenant }

      it 'strips the port and resolves the tenant' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.tenant).to eq(tenant)
      end
    end

    context 'with unknown hostname' do
      let(:hostname) { 'unknown.example.com' }

      it 'returns 404' do
        status, headers, body = middleware.call(env)

        expect(status).to eq(404)
        expect(headers['Content-Type']).to eq('text/html')
        expect(body).to eq([ 'Tenant not found' ])
        expect(Current.tenant).to be_nil
      end
    end

    context 'with disabled tenant' do
      let(:hostname) { 'disabled.example.com' }
      let(:tenant) { create(:tenant, hostname: 'disabled.example.com', slug: 'disabled', status: :disabled) }

      before { tenant }

      it 'returns 404' do
        status, _, body = middleware.call(env)

        expect(status).to eq(404)
        expect(body).to eq([ 'Tenant not found' ])
        expect(Current.tenant).to be_nil
      end
    end

    context 'with private_access tenant' do
      let(:hostname) { 'private.example.com' }
      let(:tenant) { create(:tenant, hostname: 'private.example.com', slug: 'private', status: :private_access) }

      before { tenant }

      it 'allows access to private_access tenants' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.tenant).to eq(tenant)
      end
    end

    context 'with health check endpoint' do
      let(:hostname) { 'ainews.cx' }
      let(:env) { { 'HTTP_HOST' => hostname, 'PATH_INFO' => '/up' } }

      it 'skips tenant resolution' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.tenant).to be_nil
        expect(app).to have_received(:call).with(env)
      end
    end

    context 'with localhost in development' do
      let(:hostname) { 'localhost' }
      let(:root_tenant) { create(:tenant, hostname: 'curated.cx', slug: 'root') }

      before do
        root_tenant
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'resolves to root tenant' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.tenant).to eq(root_tenant)
      end
    end

    context 'with subdomain in development' do
      let(:hostname) { 'ai.localhost' }
      let(:tenant) { create(:tenant, hostname: 'ainews.cx', slug: 'ai') }
      let(:root_tenant) { create(:tenant, hostname: 'curated.cx', slug: 'root') }

      before do
        tenant
        root_tenant
        allow(Rails.env).to receive(:development?).and_return(true)
      end

      it 'resolves tenant by subdomain slug' do
        status, _ = middleware.call(env)

        expect(status).to eq(200)
        expect(Current.tenant).to eq(tenant)
      end
    end

    context 'with missing HTTP_HOST' do
      let(:env) { {} }

      it 'handles gracefully' do
        status, _, body = middleware.call(env)

        expect(status).to eq(404)
        expect(body).to eq([ 'Tenant not found' ])
        expect(Current.tenant).to be_nil
      end
    end

    context 'when database error occurs' do
      let(:hostname) { 'test.example.com' }

      before do
        allow(Tenant).to receive(:find_by_hostname!).and_raise(ActiveRecord::StatementInvalid, 'Database error')
      end

      it 'handles the error gracefully' do
        status, _, body = middleware.call(env)

        expect(status).to eq(404)
        expect(body).to eq([ 'Tenant not found' ])
        expect(Current.tenant).to be_nil
      end
    end
  end
end
