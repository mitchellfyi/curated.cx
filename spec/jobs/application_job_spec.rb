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
end