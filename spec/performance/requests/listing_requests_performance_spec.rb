require 'rails_helper'

RSpec.describe 'Listing Requests Performance', type: :performance, performance: true do
  let!(:tenant) { create(:tenant) }
  let!(:category) { create(:category, tenant: tenant) }
  let!(:listings) { create_list(:listing, 30, tenant: tenant, category: category) }

  describe 'GET /listings' do
    it 'should respond within performance threshold' do
      result = measure_time do
        get listings_path
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end

    it 'should not trigger N+1 queries' do
      analysis = detect_n_plus_one do
        get listings_path
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 3)
    end

    it 'should handle search efficiently' do
      result = measure_time do
        get listings_path, params: { search: 'test' }
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end

    it 'should handle filtering efficiently' do
      result = measure_time do
        get listings_path, params: { category_id: category.id }
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /listings/:id' do
    let(:listing) { listings.first }

    it 'should respond within performance threshold' do
      result = measure_time do
        get listing_path(listing)
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end

    it 'should load listing with associations efficiently' do
      analysis = detect_n_plus_one do
        get listing_path(listing)
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 2)
    end
  end

  describe 'GET /listings with pagination' do
    it 'should handle pagination efficiently' do
      result = measure_time do
        get listings_path, params: { page: 2, per_page: 10 }
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end

    it 'should handle large page sizes efficiently' do
      result = measure_time do
        get listings_path, params: { per_page: 50 }
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /listings with sorting' do
    it 'should handle sorting by created_at efficiently' do
      result = measure_time do
        get listings_path, params: { sort: 'created_at', direction: 'desc' }
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end

    it 'should handle sorting by title efficiently' do
      result = measure_time do
        get listings_path, params: { sort: 'title', direction: 'asc' }
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Complex listing queries' do
    it 'should handle multiple filters efficiently' do
      result = measure_time do
        get listings_path, params: { 
          category_id: category.id, 
          search: 'test',
          sort: 'created_at',
          direction: 'desc'
        }
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end

    it 'should handle date range filtering efficiently' do
      result = measure_time do
        get listings_path, params: { 
          start_date: 1.week.ago.to_date,
          end_date: Date.current
        }
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'Memory usage during requests' do
    it 'should not exceed memory limits for listing index' do
      memory_report = profile_memory do
        get listings_path
      end

      expect_memory_usage_within_limit(memory_report.total_allocated_memsize)
    end

    it 'should not exceed memory limits for listing show' do
      memory_report = profile_memory do
        get listing_path(listings.first)
      end

      expect_memory_usage_within_limit(memory_report.total_allocated_memsize)
    end
  end

  describe 'Concurrent request handling' do
    it 'should handle concurrent listing requests' do
      results = []
      threads = []
      
      5.times do
        threads << Thread.new do
          result = measure_time do
            get listings_path
          end
          results << result
        end
      end
      
      threads.each(&:join)
      
      average_time = results.sum { |r| r[:execution_time] } / results.length
      expect_performance_within_threshold(average_time, :response_time)
    end
  end
end
