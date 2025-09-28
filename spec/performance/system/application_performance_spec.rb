require 'rails_helper'

RSpec.describe 'Application Performance', type: :performance do
  let!(:tenant) { create(:tenant) }
  let!(:categories) { create_list(:category, 3, tenant: tenant) }
  let!(:listings) { create_list(:listing, 15, tenant: tenant, category: categories.sample) }

  describe 'Homepage performance' do
    it 'should load within performance threshold' do
      result = measure_time do
        visit root_path
      end

      expect_performance_within_threshold(result[:execution_time], :page_load_time)
      expect(page).to have_content(tenant.name)
    end

    it 'should not trigger excessive queries' do
      analysis = detect_n_plus_one do
        visit root_path
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 5)
    end

    it 'should handle memory efficiently' do
      memory_report = profile_memory do
        visit root_path
      end

      expect_memory_usage_within_limit(memory_report.total_allocated_memsize)
    end
  end

  describe 'Tenant page performance' do
    it 'should load tenant page efficiently' do
      result = measure_time do
        visit tenant_path(tenant)
      end

      expect_performance_within_threshold(result[:execution_time], :page_load_time)
      expect(page).to have_content(tenant.name)
    end

    it 'should load tenant listings efficiently' do
      result = measure_time do
        visit tenant_listings_path(tenant)
      end

      expect_performance_within_threshold(result[:execution_time], :page_load_time)
      expect(page).to have_content('Listings')
    end
  end

  describe 'Listing page performance' do
    let(:listing) { listings.first }

    it 'should load individual listing efficiently' do
      result = measure_time do
        visit listing_path(listing)
      end

      expect_performance_within_threshold(result[:execution_time], :page_load_time)
      expect(page).to have_content(listing.title)
    end

    it 'should not trigger N+1 queries on listing page' do
      analysis = detect_n_plus_one do
        visit listing_path(listing)
      end

      expect_no_n_plus_one_queries(analysis)
      expect_query_count_within_limit(analysis[:total_queries], 3)
    end
  end

  describe 'Search performance' do
    it 'should handle search efficiently' do
      result = measure_time do
        visit listings_path
        fill_in 'search', with: 'test'
        click_button 'Search'
      end

      expect_performance_within_threshold(result[:execution_time], :page_load_time)
    end

    it 'should handle empty search results efficiently' do
      result = measure_time do
        visit listings_path
        fill_in 'search', with: 'nonexistent'
        click_button 'Search'
      end

      expect_performance_within_threshold(result[:execution_time], :page_load_time)
    end
  end

  describe 'Pagination performance' do
    it 'should handle pagination efficiently' do
      result = measure_time do
        visit listings_path
        click_link 'Next'
      end

      expect_performance_within_threshold(result[:execution_time], :page_load_time)
    end

    it 'should handle large page sizes efficiently' do
      result = measure_time do
        visit listings_path
        select '50', from: 'per_page'
        click_button 'Update'
      end

      expect_performance_within_threshold(result[:execution_time], :page_load_time)
    end
  end

  describe 'Navigation performance' do
    it 'should navigate between pages efficiently' do
      # Start at homepage
      visit root_path
      
      # Navigate to tenant page
      result1 = measure_time do
        click_link tenant.name
      end
      expect_performance_within_threshold(result1[:execution_time], :page_load_time)
      
      # Navigate to listings
      result2 = measure_time do
        click_link 'Listings'
      end
      expect_performance_within_threshold(result2[:execution_time], :page_load_time)
      
      # Navigate to individual listing
      result3 = measure_time do
        click_link listings.first.title
      end
      expect_performance_within_threshold(result3[:execution_time], :page_load_time)
    end
  end

  describe 'Memory usage across page loads' do
    it 'should not accumulate memory across multiple page loads' do
      initial_memory = profile_memory { visit root_path }
      
      # Load multiple pages
      5.times do
        visit listings_path
        visit tenant_path(tenant)
        visit root_path
      end
      
      final_memory = profile_memory { visit root_path }
      
      # Memory usage should not grow significantly
      memory_growth = final_memory.total_allocated_memsize - initial_memory.total_allocated_memsize
      expect(memory_growth).to be < 10.megabytes
    end
  end

  describe 'Concurrent user simulation' do
    it 'should handle multiple concurrent page loads' do
      results = []
      threads = []
      
      # Simulate 3 concurrent users
      3.times do
        threads << Thread.new do
          result = measure_time do
            visit root_path
            visit listings_path
            visit tenant_path(tenant)
          end
          results << result
        end
      end
      
      threads.each(&:join)
      
      average_time = results.sum { |r| r[:execution_time] } / results.length
      expect_performance_within_threshold(average_time, :page_load_time)
    end
  end

  describe 'JavaScript performance' do
    it 'should load JavaScript efficiently' do
      result = measure_time do
        visit root_path
        # Wait for JavaScript to load
        sleep 0.1
      end

      expect_performance_within_threshold(result[:execution_time], :page_load_time)
    end

    it 'should handle Turbo navigation efficiently' do
      visit root_path
      
      result = measure_time do
        click_link tenant.name
        # Wait for Turbo to complete
        sleep 0.1
      end

      expect_performance_within_threshold(result[:execution_time], :response_time)
    end
  end
end
