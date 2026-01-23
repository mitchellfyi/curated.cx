# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  describe 'job configuration' do
    it 'inherits from ActiveJob::Base' do
      expect(described_class.superclass).to eq(ActiveJob::Base)
    end

    it 'configures the queue adapter' do
      expect(ApplicationJob.queue_adapter_name).to be_present
    end

    it 'has default queue name' do
      expect(ApplicationJob.queue_name).to be_present
    end
  end

  describe 'tenant context handling' do
    let(:tenant) { create(:tenant) }
    let(:test_job_class) do
      Class.new(ApplicationJob) do
        def perform(tenant_id)
          # Simple test job that uses tenant context
          Current.tenant = Tenant.find(tenant_id)
          raise "Tenant not set" unless Current.tenant.present?
          "Success with tenant #{Current.tenant.slug}"
        end
      end
    end

    it 'can access tenant context within job execution' do
      result = test_job_class.perform_now(tenant.id)
      expect(result).to include("Success with tenant #{tenant.slug}")
    end

    it 'handles job execution without raising errors' do
      expect {
        test_job_class.perform_now(tenant.id)
      }.not_to raise_error
    end
  end

  describe 'error handling' do
    let(:failing_job_class) do
      Class.new(ApplicationJob) do
        def perform
          raise StandardError, "Test error"
        end
      end
    end

    it 'properly raises errors during job execution' do
      expect {
        failing_job_class.perform_now
      }.to raise_error(StandardError, "Test error")
    end
  end

  describe 'retry_on configuration' do
    # rescue_handlers format is [["ErrorClassName", proc], ...]
    it 'retries on ExternalServiceError' do
      handler = described_class.rescue_handlers.find { |h| h[0] == "ExternalServiceError" }
      expect(handler).to be_present
    end

    it 'retries on DnsError' do
      handler = described_class.rescue_handlers.find { |h| h[0] == "DnsError" }
      expect(handler).to be_present
    end

    it 'retries on ActiveRecord::Deadlocked' do
      handler = described_class.rescue_handlers.find { |h| h[0] == "ActiveRecord::Deadlocked" }
      expect(handler).to be_present
    end
  end

  describe 'discard_on configuration' do
    # discard_on uses the same rescue_handlers array but with different proc behavior
    it 'discards on ConfigurationError' do
      handler = described_class.rescue_handlers.find { |h| h[0] == "ConfigurationError" }
      expect(handler).to be_present
    end

    it 'discards on ActiveRecord::RecordNotFound' do
      handler = described_class.rescue_handlers.find { |h| h[0] == "ActiveRecord::RecordNotFound" }
      expect(handler).to be_present
    end
  end

  describe '#log_job_error' do
    let(:tenant) { create(:tenant) }
    let(:site) { create(:site, tenant: tenant) }
    let(:logging_job_class) do
      Class.new(ApplicationJob) do
        def perform(should_fail: false)
          if should_fail
            log_job_error(StandardError.new("Test failure"), listing_id: 123)
          end
        end

        # Expose protected method for testing
        public :log_job_error
      end
    end

    before do
      Current.tenant = tenant
      Current.site = site
    end

    after do
      Current.tenant = nil
      Current.site = nil
    end

    it 'logs error with structured context' do
      job = logging_job_class.new
      error = StandardError.new("Connection timeout")

      expect(Rails.logger).to receive(:error).with(a_string_matching(/Connection timeout/))

      job.log_job_error(error)
    end

    it 'includes job class name in log message' do
      job = logging_job_class.new
      error = StandardError.new("Error")

      expect(Rails.logger).to receive(:error).with(a_string_matching(/failed:/))

      job.log_job_error(error)
    end

    it 'includes error class in log message' do
      job = logging_job_class.new
      error = ExternalServiceError.new("API timeout")

      expect(Rails.logger).to receive(:error).with(a_string_matching(/ExternalServiceError/))

      job.log_job_error(error)
    end

    it 'includes tenant_id in context when tenant is set' do
      job = logging_job_class.new
      error = StandardError.new("Error")

      expect(Rails.logger).to receive(:error).with(a_string_matching(/"tenant_id":#{tenant.id}/))

      job.log_job_error(error)
    end

    it 'includes site_id in context when site is set' do
      job = logging_job_class.new
      error = StandardError.new("Error")

      expect(Rails.logger).to receive(:error).with(a_string_matching(/"site_id":#{site.id}/))

      job.log_job_error(error)
    end

    it 'includes custom context passed as keyword arguments' do
      job = logging_job_class.new
      error = StandardError.new("Error")

      expect(Rails.logger).to receive(:error).with(a_string_matching(/"listing_id":456/))

      job.log_job_error(error, listing_id: 456)
    end

    it 'includes job_id in context' do
      job = logging_job_class.new
      job.job_id = "abc-123"
      error = StandardError.new("Error")

      expect(Rails.logger).to receive(:error).with(a_string_matching(/"job_id":"abc-123"/))

      job.log_job_error(error)
    end
  end

  describe '#log_job_warning' do
    let(:tenant) { create(:tenant) }
    let(:site) { create(:site, tenant: tenant) }
    let(:logging_job_class) do
      Class.new(ApplicationJob) do
        def perform
          log_job_warning("Slow response detected", response_time: 5.2)
        end

        # Expose protected method for testing
        public :log_job_warning
      end
    end

    before do
      Current.tenant = tenant
      Current.site = site
    end

    after do
      Current.tenant = nil
      Current.site = nil
    end

    it 'logs warning with message' do
      job = logging_job_class.new

      expect(Rails.logger).to receive(:warn).with(a_string_matching(/Slow response detected/))

      job.log_job_warning("Slow response detected")
    end

    it 'includes tenant context' do
      job = logging_job_class.new

      expect(Rails.logger).to receive(:warn).with(a_string_matching(/"tenant_id":#{tenant.id}/))

      job.log_job_warning("Warning message")
    end

    it 'includes custom context' do
      job = logging_job_class.new

      expect(Rails.logger).to receive(:warn).with(a_string_matching(/"response_time":5.2/))

      job.log_job_warning("Slow response", response_time: 5.2)
    end
  end
end
