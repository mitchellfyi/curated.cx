require 'rails_helper'

RSpec.describe 'Tenant Requests Performance', type: :performance, performance: true do
  let!(:tenant) { create(:tenant) }
  let!(:categories) { create_list(:category, 5, tenant: tenant) }
  let!(:listings) { create_list(:listing, 20, tenant: tenant, category: categories.sample) }

  describe 'GET /tenants' do
    it 'should respond within performance threshold' do
      result = measure_time do
        get tenants_path
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end

    it 'should not trigger N+1 queries' do
      analysis = detect_n_plus_one do
        get tenants_path
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 5)
    end

    it 'should handle concurrent requests efficiently' do
      # Simulate concurrent requests
      results = []
      threads = []
      
      5.times do
        threads << Thread.new do
          result = measure_time do
            get tenants_path
          end
          results << result
        end
      end
      
      threads.each(&:join)
      
      average_time = results.sum { |r| r[:execution_time] } / results.length
      expect_performance_within_threshold(average_time, :response_time)
    end
  end

  describe 'GET /tenants/:id' do
    it 'should respond within performance threshold' do
      result = measure_time do
        get tenant_path(tenant)
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end

    it 'should load tenant with associations efficiently' do
      analysis = detect_n_plus_one do
        get tenant_path(tenant)
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 3)
    end
  end

  describe 'GET /tenants/:id/listings' do
    it 'should respond within performance threshold' do
      result = measure_time do
        get tenant_listings_path(tenant)
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end

    it 'should load listings efficiently' do
      analysis = detect_n_plus_one do
        get tenant_listings_path(tenant)
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 3)
    end

    it 'should handle pagination efficiently' do
      result = measure_time do
        get tenant_listings_path(tenant), params: { page: 2, per_page: 10 }
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Load testing endpoints' do
    it 'should handle load on tenants index' do
      # This would require a running server, so we'll simulate with direct controller calls
      controller = TenantsController.new
      
      results = []
      10.times do
        result = measure_time do
          controller.index
        end
        results << result
      end
      
      average_time = results.sum { |r| r[:execution_time] } / results.length
      expect_performance_within_threshold(average_time, :response_time)
    end
  end

  describe 'Memory usage during requests' do
    it 'should not exceed memory limits' do
      memory_report = profile_memory do
        get tenant_path(tenant)
      end

      expect_memory_usage_within_limit(memory_report.total_allocated_memsize)
    end
  end
end
