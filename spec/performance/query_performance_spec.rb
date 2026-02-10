# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Query Performance', type: :request do
  let(:tenant) { create(:tenant, :enabled) }
  let!(:category) { create(:category, tenant: tenant) }
  let!(:entries) { create_list(:entry, :directory, 10, :published, tenant: tenant, category: category) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe 'N+1 query prevention' do
    it 'loads home page without N+1 queries on entries' do
      # Warm up
      get root_path

      # Count queries
      query_count = 0
      callback = lambda { |*args| query_count += 1 }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get root_path
      end

      # Should not have excessive queries (base queries + 1 per model type max)
      # Allow some flexibility for different eager loading strategies
      expect(query_count).to be < 20
    end

    it 'loads categories index without N+1 queries' do
      create_list(:category, 5, tenant: tenant)

      query_count = 0
      callback = lambda { |*args| query_count += 1 }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get categories_path
      end

      # Allow reasonable query count for multi-tenant context setup + page load
      expect(query_count).to be < 25
    end

    it 'loads category show without N+1 queries on entries' do
      create_list(:entry, :directory, 10, :published, tenant: tenant, category: category)

      query_count = 0
      callback = lambda { |*args| query_count += 1 }
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        get category_path(category)
      end

      # Allow reasonable query count for multi-tenant context setup + page load
      expect(query_count).to be < 25
    end
  end

  describe 'Response times' do
    it 'home page responds quickly' do
      start_time = Time.current
      get root_path
      elapsed = Time.current - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 2.seconds
    end

    it 'categories page responds quickly' do
      start_time = Time.current
      get categories_path
      elapsed = Time.current - start_time

      expect(response).to have_http_status(:success)
      expect(elapsed).to be < 2.seconds
    end
  end

  describe 'Database efficiency' do
    it 'uses indexes for common queries' do
      # This test verifies that indexes exist on commonly queried columns
      indexes = ActiveRecord::Base.connection.indexes(:entries)
      index_columns = indexes.flat_map(&:columns)

      # Should have indexes on foreign keys and commonly filtered columns
      expect(index_columns).to include('tenant_id').or include('site_id')
      expect(index_columns).to include('category_id')
    end

    it 'categories table has proper indexes' do
      indexes = ActiveRecord::Base.connection.indexes(:categories)
      index_columns = indexes.flat_map(&:columns)

      expect(index_columns).to include('site_id').or include('tenant_id')
    end
  end
end
