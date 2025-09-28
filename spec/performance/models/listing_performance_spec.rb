require 'rails_helper'

RSpec.describe 'Listing Performance', type: :performance do
  let!(:tenant) { create(:tenant) }
  let!(:category) { create(:category, tenant: tenant) }
  let!(:listings) { create_list(:listing, 50, tenant: tenant, category: category) }

  describe 'Listing queries' do
    it 'should load listings with associations efficiently' do
      analysis = detect_n_plus_one do
        listings = Listing.includes(:tenant, :category).limit(20)
        listings.each do |listing|
          listing.tenant.name
          listing.category.name
        end
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 2)
    end

    it 'should perform listing search efficiently' do
      benchmark_result = benchmark_database_operation do
        Listing.search('test').limit(20).to_a
      end

      expect_performance_within_threshold(benchmark_result[:execution_time], :query_time)
      expect_query_count_within_limit(benchmark_result[:query_count], 2)
    end

    it 'should load listing statistics efficiently' do
      benchmark_result = benchmark_database_operation do
        {
          total_listings: Listing.count,
          active_listings: Listing.where(active: true).count,
          recent_listings: Listing.where('created_at > ?', 1.week.ago).count
        }
      end

      expect_performance_within_threshold(benchmark_result[:execution_time], :query_time)
      expect_query_count_within_limit(benchmark_result[:query_count], 3)
    end

    it 'should handle pagination efficiently' do
      benchmark_result = benchmark_database_operation do
        Listing.page(1).per(20).to_a
      end

      expect_performance_within_threshold(benchmark_result[:execution_time], :query_time)
      expect_query_count_within_limit(benchmark_result[:query_count], 2)
    end
  end

  describe 'Listing filtering and sorting' do
    it 'should filter by category efficiently' do
      benchmark_result = benchmark_database_operation do
        Listing.where(category: category).limit(20).to_a
      end

      expect_performance_within_threshold(benchmark_result[:execution_time], :query_time)
      expect_query_count_within_limit(benchmark_result[:query_count], 1)
    end

    it 'should sort by created_at efficiently' do
      benchmark_result = benchmark_database_operation do
        Listing.order(created_at: :desc).limit(20).to_a
      end

      expect_performance_within_threshold(benchmark_result[:execution_time], :query_time)
      expect_query_count_within_limit(benchmark_result[:query_count], 1)
    end

    it 'should handle complex queries efficiently' do
      benchmark_result = benchmark_database_operation do
        Listing.joins(:category, :tenant)
               .where(categories: { active: true })
               .where(tenants: { active: true })
               .order(created_at: :desc)
               .limit(20)
               .to_a
      end

      expect_performance_within_threshold(benchmark_result[:execution_time], :query_time)
      expect_query_count_within_limit(benchmark_result[:query_count], 1)
    end
  end

  describe 'Listing memory usage' do
    it 'should not exceed memory limits when loading large datasets' do
      memory_report = profile_memory do
        listings = Listing.includes(:tenant, :category).limit(100)
        listings.each do |listing|
          listing.tenant.name
          listing.category.name
        end
      end

      expect_memory_usage_within_limit(memory_report.total_allocated_memsize)
    end
  end

  describe 'Listing N+1 query prevention' do
    it 'should detect N+1 queries without includes' do
      analysis = detect_n_plus_one do
        listings = Listing.limit(10)
        listings.each do |listing|
          listing.tenant.name
          listing.category.name
        end
      end

      # This should detect N+1 queries
      expect(analysis[:total_queries]).to be > 10, 'Expected N+1 queries to be detected'
    end

    it 'should prevent N+1 with proper includes' do
      analysis = detect_n_plus_one do
        listings = Listing.includes(:tenant, :category).limit(10)
        listings.each do |listing|
          listing.tenant.name
          listing.category.name
        end
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 1)
    end
  end
end
