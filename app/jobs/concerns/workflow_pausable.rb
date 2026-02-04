# frozen_string_literal: true

# Concern for jobs that can be paused via WorkflowPauseService.
# Include this in any job that should respect workflow pauses.
#
# Usage:
#   class MyJob < ApplicationJob
#     include WorkflowPausable
#     self.workflow_type = :rss_ingestion
#
#     def perform(source_id)
#       return if workflow_paused?(source_id: source_id)
#       # ... job logic
#     end
#   end
#
module WorkflowPausable
  extend ActiveSupport::Concern

  included do
    class_attribute :workflow_type, default: nil
  end

  private

  # Check if the workflow is paused for this job's context.
  # Sets @source, @site, @tenant if source_id provided.
  #
  # @param source_id [Integer, nil] Optional source ID to check
  # @param tenant [Tenant, nil] Optional tenant to check
  # @param source [Source, nil] Optional source to check
  # @return [Boolean] true if paused and job should skip
  def workflow_paused?(source_id: nil, tenant: nil, source: nil)
    # Resolve source if ID provided
    if source_id && source.nil?
      source = Source.find_by(id: source_id)
      return false unless source # If source doesn't exist, let the job handle it
    end

    # Resolve tenant from source or instance variable
    tenant ||= source&.tenant || @tenant

    # Check if paused
    is_paused = WorkflowPauseService.paused?(
      self.class.workflow_type,
      tenant: tenant,
      source: source
    )

    if is_paused
      log_workflow_paused(source: source, tenant: tenant)
      update_source_status_paused(source) if source
      return true
    end

    false
  end

  # Convenience method to check pause and set up context
  # @param source [Source] The source being processed
  # @return [Boolean] true if paused and job should skip
  def check_pause_and_set_context!(source)
    @source = source
    @site = source.site
    @tenant = source.tenant

    # Set Current context
    Current.tenant = @tenant
    Current.site = @site

    workflow_paused?(source: source, tenant: @tenant)
  end

  def log_workflow_paused(source:, tenant:)
    pause = WorkflowPause.find_active(self.class.workflow_type, tenant: tenant, source: source)

    log_job_info(
      "Workflow paused - skipping",
      workflow_type: self.class.workflow_type,
      pause_id: pause&.id,
      pause_reason: pause&.reason,
      paused_since: pause&.paused_at,
      global: pause&.global?,
      source_id: source&.id,
      tenant_id: tenant&.id
    )
  end

  def update_source_status_paused(source)
    return unless source.respond_to?(:update_run_status)

    source.update_run_status("workflow_paused")
  end
end
