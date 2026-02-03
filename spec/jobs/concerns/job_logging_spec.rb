# frozen_string_literal: true

require "rails_helper"

RSpec.describe JobLogging do
  let(:test_job_class) do
    Class.new(ApplicationJob) do
      include JobLogging

      def self.name
        "TestJob"
      end

      def perform_with_logging
        with_job_logging("test operation") do
          "result"
        end
      end

      def perform_with_error
        with_job_logging("failing operation") do
          raise StandardError, "test error"
        end
      end

      def perform_info_log
        log_job_info("test info", key: "value")
      end

      def perform_warning_log
        log_job_warning("test warning", code: 123)
      end

      def perform_error_log
        log_job_error(StandardError.new("test error"), context: "testing")
      end
    end
  end

  let(:job) { test_job_class.new }

  describe "#with_job_logging" do
    it "logs start and completion" do
      expect(Rails.logger).to receive(:info).twice
      result = job.perform_with_logging
      expect(result).to eq("result")
    end

    it "logs error and re-raises on failure" do
      expect(Rails.logger).to receive(:info).once # start
      expect(Rails.logger).to receive(:error).once # error

      expect { job.perform_with_error }.to raise_error(StandardError, "test error")
    end
  end

  describe "#log_job_info" do
    it "logs info with context" do
      expect(Rails.logger).to receive(:info).with(/test info.*key.*value/)
      job.perform_info_log
    end
  end

  describe "#log_job_warning" do
    it "logs warning with context" do
      expect(Rails.logger).to receive(:warn).with(/test warning.*code.*123/)
      job.perform_warning_log
    end
  end

  describe "#log_job_error" do
    it "logs error with backtrace" do
      expect(Rails.logger).to receive(:error).with(/StandardError.*test error.*context.*testing/)
      job.perform_error_log
    end
  end
end
