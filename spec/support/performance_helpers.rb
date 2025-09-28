# Performance testing helpers and utilities

module PerformanceHelpers
  # Performance thresholds
  PERFORMANCE_THRESHOLDS = {
    page_load_time: 2.0,      # seconds
    query_time: 0.1,          # seconds
    memory_usage: 50.megabytes, # bytes
    n_plus_one_threshold: 5,   # max queries per operation
    response_time: 0.5         # seconds
  }.freeze

  # Memory profiling helper
  def profile_memory(&block)
    require 'memory_profiler'
    MemoryProfiler.report(&block)
  end

  # Query counting helper
  def count_queries(&block)
    query_count = 0
    callback = lambda do |*args|
      query_count += 1 unless args.last[:sql].match?(/^(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    query_count
  end

  # Performance timing helper
  def measure_time(&block)
    start_time = Time.current
    result = block.call
    end_time = Time.current
    execution_time = end_time - start_time

    { result: result, execution_time: execution_time }
  end

  # N+1 query detection helper
  def detect_n_plus_one(&block)
    queries = []
    callback = lambda do |*args|
      queries << args.last[:sql] unless args.last[:sql].match?(/^(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)

    # Group queries by table and operation
    grouped_queries = queries.group_by do |sql|
      if sql.match?(/FROM\s+(\w+)/i)
        table = sql.match(/FROM\s+(\w+)/i)[1]
        operation = sql.match(/^(SELECT|INSERT|UPDATE|DELETE)/i)[1]
        "#{table}.#{operation}"
      else
        'unknown'
      end
    end

    # Detect potential N+1 patterns
    n_plus_one_issues = grouped_queries.select do |_key, query_list|
      query_list.length > PERFORMANCE_THRESHOLDS[:n_plus_one_threshold]
    end

    {
      total_queries: queries.length,
      grouped_queries: grouped_queries,
      n_plus_one_issues: n_plus_one_issues
    }
  end

  # Database performance helper
  def benchmark_database_operation(&block)
    result = nil
    query_count = 0
    total_time = 0

    callback = lambda do |*args|
      query_count += 1
      total_time += args.last[:duration] unless args.last[:sql].match?(/^(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      result = measure_time(&block)
    end

    {
      result: result[:result],
      execution_time: result[:execution_time],
      query_count: query_count,
      total_query_time: total_time,
      average_query_time: query_count > 0 ? total_time / query_count : 0
    }
  end

  # Load testing helper for request specs
  def load_test_endpoint(endpoint, iterations: 10, concurrency: 5)
    require 'net/http'
    require 'uri'
    require 'benchmark'

    uri = URI(endpoint)
    results = []

    Benchmark.measure do
      threads = []
      concurrency.times do
        threads << Thread.new do
          iterations.times do
            start_time = Time.current
            response = Net::HTTP.get_response(uri)
            end_time = Time.current

            results << {
              response_time: end_time - start_time,
              status_code: response.code.to_i,
              success: response.is_a?(Net::HTTPSuccess)
            }
          end
        end
      end
      threads.each(&:join)
    end

    {
      total_requests: results.length,
      successful_requests: results.count { |r| r[:success] },
      failed_requests: results.count { |r| !r[:success] },
      average_response_time: results.sum { |r| r[:response_time] } / results.length,
      min_response_time: results.map { |r| r[:response_time] }.min,
      max_response_time: results.map { |r| r[:response_time] }.max,
      p95_response_time: results.map { |r| r[:response_time] }.sort[(results.length * 0.95).to_i]
    }
  end

  # Performance assertion helpers
  def expect_performance_within_threshold(actual_time, threshold_key)
    threshold = PERFORMANCE_THRESHOLDS[threshold_key]
    expect(actual_time).to be <= threshold,
      "Expected #{threshold_key} to be <= #{threshold}s, but was #{actual_time}s"
  end

  def expect_query_count_within_limit(actual_count, limit = PERFORMANCE_THRESHOLDS[:n_plus_one_threshold])
    expect(actual_count).to be <= limit,
      "Expected query count to be <= #{limit}, but was #{actual_count}"
  end

  def expect_no_n_plus_one_queries(analysis_result)
    expect(analysis_result[:n_plus_one_issues]).to be_empty,
      "N+1 queries detected: #{analysis_result[:n_plus_one_issues].keys.join(', ')}"
  end

  def expect_memory_usage_within_limit(actual_usage, limit = PERFORMANCE_THRESHOLDS[:memory_usage])
    expect(actual_usage).to be <= limit,
      "Expected memory usage to be <= #{limit}, but was #{actual_usage}"
  end
end

# Include performance helpers in RSpec
RSpec.configure do |config|
  config.include PerformanceHelpers, type: :performance
  config.include PerformanceHelpers, type: :model
  config.include PerformanceHelpers, type: :request
  config.include PerformanceHelpers, type: :system
end

# Performance test tags
RSpec.configure do |config|
  config.define_derived_metadata(file_path: %r{/spec/performance/}) do |metadata|
    metadata[:type] = :performance
  end
end
