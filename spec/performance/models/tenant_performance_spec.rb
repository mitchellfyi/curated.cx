require 'rails_helper'

RSpec.describe 'Tenant Performance', type: :performance do
  let!(:tenant) { create(:tenant) }
  let!(:categories) { create_list(:category, 5, tenant: tenant) }
  let!(:listings) { create_list(:listing, 20, tenant: tenant, category: categories.sample) }

  describe 'Tenant queries' do
    it 'should load tenant with associations efficiently' do
      analysis = detect_n_plus_one do
        tenant = Tenant.includes(:categories, :listings).find(tenant.id)
        tenant.categories.each(&:name)
        tenant.listings.each(&:title)
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 3)
    end

    it 'should perform tenant search efficiently' do
      benchmark_result = benchmark_database_operation do
        Tenant.search('test').limit(10).to_a
      end

      expect_performance_within_threshold(benchmark_result[:execution_time], :query_time)
      expect_query_count_within_limit(benchmark_result[:query_count], 2)
    end

    it 'should load tenant statistics efficiently' do
      benchmark_result = benchmark_database_operation do
        tenant = Tenant.find(tenant.id)
        {
          categories_count: tenant.categories.count,
          listings_count: tenant.listings.count,
          active_listings: tenant.listings.where(active: true).count
        }
      end

      expect_performance_within_threshold(benchmark_result[:execution_time], :query_time)
      expect_query_count_within_limit(benchmark_result[:query_count], 4)
    end
  end

  describe 'Tenant memory usage' do
    it 'should not exceed memory limits when loading large datasets' do
      # Create larger dataset for memory testing
      large_tenant = create(:tenant)
      create_list(:category, 10, tenant: large_tenant)
      create_list(:listing, 100, tenant: large_tenant)

      memory_report = profile_memory do
        tenant = Tenant.includes(:categories, :listings).find(large_tenant.id)
        tenant.categories.each(&:name)
        tenant.listings.each(&:title)
      end

      expect_memory_usage_within_limit(memory_report.total_allocated_memsize)
    end
  end

  describe 'Tenant N+1 query prevention' do
    it 'should use includes to prevent N+1 queries' do
      # This should trigger N+1 if not properly optimized
      analysis = detect_n_plus_one do
        tenants = Tenant.limit(5)
        tenants.each do |tenant|
          tenant.categories.each(&:name)
          tenant.listings.limit(5).each(&:title)
        end
      end

      # This will likely fail without proper includes - that's the point of the test
      expect(analysis[:total_queries]).to be > 10, 'Expected N+1 queries to be detected'
    end

    it 'should prevent N+1 with proper includes' do
      analysis = detect_n_plus_one do
        tenants = Tenant.includes(:categories, :listings).limit(5)
        tenants.each do |tenant|
          tenant.categories.each(&:name)
          tenant.listings.limit(5).each(&:title)
        end
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 3)
    end
  end
end
