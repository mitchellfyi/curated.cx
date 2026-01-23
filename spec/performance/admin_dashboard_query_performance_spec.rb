# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin Dashboard Query Performance', type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let!(:site) { tenant.sites.first }
  let!(:category) { create(:category, tenant: tenant, site: site) }
  let!(:listings) { create_list(:listing, 10, :published, tenant: tenant, category: category) }
  let(:admin_user) { create(:user, :admin) }

  before do
    sign_in admin_user
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe 'N+1 query prevention' do
    it 'loads admin dashboard with minimal queries' do
      # Warm up - first request loads caches
      get admin_root_path

      # Count queries on second request
      query_count = 0
      data_queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        # Skip schema and transaction queries
        sql = payload[:sql]
        next if sql.include?('SCHEMA')
        next if sql.include?('TRANSACTION')
        next if sql.include?('SELECT a.attname')
        next if sql.include?('pg_')

        query_count += 1
        data_queries << sql
      end

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get admin_root_path
      end

      # Admin dashboard should be efficient:
      # - 1 query for tenant context (Current.tenant)
      # - 1 query for categories with eager loaded listings
      # - 1 query for recent listings with eager loaded category
      # - 1 query for consolidated stats (COUNT FILTER)
      # - Some additional queries for auth/session are acceptable
      #
      # Total should be ≤15 queries (allowing for auth overhead)
      expect(query_count).to be <= 15,
        "Expected ≤15 queries but got #{query_count}.\n\nQueries:\n#{data_queries.join("\n")}"
    end

    it 'eager loads categories with their listings association' do
      get admin_root_path

      categories = assigns(:categories)
      expect(categories).to be_present

      # Verify listings association is already loaded (no N+1)
      categories.each do |cat|
        expect(cat.association(:listings)).to be_loaded
      end
    end

    it 'eager loads recent listings with their category association' do
      get admin_root_path

      recent_listings = assigns(:recent_listings)
      expect(recent_listings).to be_present

      # Verify category association is already loaded (no N+1)
      recent_listings.each do |listing|
        expect(listing.association(:category)).to be_loaded
      end
    end

    it 'calculates stats in a single consolidated query' do
      # Create test data
      create(:listing, :published, tenant: tenant, category: category, created_at: Time.current)
      create(:listing, :unpublished, tenant: tenant, category: category)

      # Count stat-related queries
      stats_queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        stats_queries << sql if sql.include?('COUNT') || sql.include?('count')
      end

      # Warm up
      get admin_root_path

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get admin_root_path
      end

      # Should use PostgreSQL COUNT(*) FILTER in a single query
      # instead of multiple separate COUNT queries
      listing_count_queries = stats_queries.select { |q| q.include?('"listings"') }
      expect(listing_count_queries.size).to be <= 1,
        "Expected 1 consolidated stats query but found #{listing_count_queries.size}:\n#{listing_count_queries.join("\n")}"
    end
  end

  describe 'Response time' do
    it 'admin dashboard responds quickly' do
      start_time = Time.current
      get admin_root_path
      elapsed = Time.current - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 2.seconds
    end
  end

  describe 'With increased data volume' do
    before do
      # Create additional data to stress test
      create_list(:category, 5, tenant: tenant, site: site)
      create_list(:listing, 20, :published, tenant: tenant, category: category)
    end

    it 'query count does not increase with data volume' do
      # Warm up
      get admin_root_path

      # Count queries with more data
      query_count = 0
      callback = lambda do |_name, _start, _finish, _id, payload|
        sql = payload[:sql]
        next if sql.include?('SCHEMA')
        next if sql.include?('TRANSACTION')
        next if sql.include?('SELECT a.attname')
        next if sql.include?('pg_')

        query_count += 1
      end

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get admin_root_path
      end

      # Even with more data, query count should remain constant (no N+1)
      expect(query_count).to be <= 15
    end
  end
end
