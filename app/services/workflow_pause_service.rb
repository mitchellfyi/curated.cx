# frozen_string_literal: true

# Service for managing workflow pause states.
# Provides a clean API for pausing/resuming imports and AI processing.
#
# Usage:
#   WorkflowPauseService.paused?(:imports, tenant: tenant)
#   WorkflowPauseService.pause!(:imports, by: user, tenant: tenant)
#   WorkflowPauseService.resume!(:imports, by: user, tenant: tenant, process_backlog: true)
#
class WorkflowPauseService
  WORKFLOW_TYPES = %w[imports ai_processing rss_ingestion serp_api_ingestion editorialisation].freeze
  IMPORT_SUBTYPES = %w[rss serp_api_google_news serp_api_google_jobs serp_api_youtube all].freeze

  class << self
    # Check if a workflow is paused
    # Returns true if ANY applicable pause is active (global, tenant, or source)
    def paused?(workflow_type, tenant: nil, source: nil, subtype: nil)
      validate_workflow_type!(workflow_type)
      WorkflowPause.paused?(workflow_type.to_s, tenant: tenant, source: source, subtype: subtype&.to_s)
    end

    # Pause a workflow
    def pause!(workflow_type, by:, tenant: nil, source: nil, subtype: nil, reason: nil)
      validate_workflow_type!(workflow_type)

      pause = WorkflowPause.find_or_create_for(
        workflow_type: workflow_type.to_s,
        tenant: tenant,
        subtype: subtype&.to_s,
        source: source
      )

      pause.pause!(by: by, reason: reason)

      log_action(:pause, workflow_type, by: by, tenant: tenant, source: source, subtype: subtype)

      pause
    end

    # Resume a workflow
    def resume!(workflow_type, by:, tenant: nil, source: nil, subtype: nil, process_backlog: true)
      validate_workflow_type!(workflow_type)

      pause = WorkflowPause.find_by(
        workflow_type: workflow_type.to_s,
        workflow_subtype: subtype&.to_s,
        tenant: tenant,
        source: source
      )

      return nil unless pause&.paused?

      pause.resume!(by: by)

      log_action(:resume, workflow_type, by: by, tenant: tenant, source: source, subtype: subtype)

      # Process backlog if requested
      if process_backlog
        ProcessBacklogJob.perform_later(
          workflow_type: workflow_type.to_s,
          tenant_id: tenant&.id,
          source_id: source&.id,
          subtype: subtype&.to_s
        )
      end

      pause
    end

    # Get all active pauses
    def active_pauses(tenant: nil)
      scope = WorkflowPause.active
      scope = scope.where(tenant: [ nil, tenant ]) if tenant
      scope.order(created_at: :desc)
    end

    # Get pause status summary
    def status_summary(tenant: nil)
      {
        imports: {
          paused: paused?(:imports, tenant: tenant),
          subtypes: IMPORT_SUBTYPES.each_with_object({}) do |subtype, hash|
            hash[subtype] = paused?(:imports, tenant: tenant, subtype: subtype)
          end
        },
        ai_processing: {
          paused: paused?(:ai_processing, tenant: tenant)
        },
        active_pauses: active_pauses(tenant: tenant).count
      }
    end

    # Estimate backlog size for a workflow
    def backlog_size(workflow_type, tenant: nil, since: nil)
      case workflow_type.to_s
      when "imports"
        estimate_import_backlog(tenant, since)
      when "ai_processing"
        estimate_ai_backlog(tenant, since)
      else
        0
      end
    end

    private

    def validate_workflow_type!(type)
      unless WORKFLOW_TYPES.include?(type.to_s)
        raise ArgumentError, "Invalid workflow type: #{type}. Must be one of: #{WORKFLOW_TYPES.join(', ')}"
      end
    end

    def estimate_import_backlog(tenant, since)
      # Count sources that haven't run since pause started
      scope = Source.enabled
      scope = scope.where(tenant: tenant) if tenant

      if since
        scope.where("last_run_at < ? OR last_run_at IS NULL", since).count
      else
        scope.where("last_run_at < ? OR last_run_at IS NULL", 1.hour.ago).count
      end
    end

    def estimate_ai_backlog(tenant, since)
      # Count content items awaiting editorialisation
      scope = ContentItem.published.where(editorialised_at: nil)
      scope = scope.joins(:source).where(sources: { tenant: tenant }) if tenant
      scope = scope.where("content_items.created_at > ?", since) if since
      scope.count
    end

    def log_action(action, workflow_type, by:, tenant:, source:, subtype:)
      Rails.logger.info(
        "[WorkflowPauseService] #{action.upcase} #{workflow_type}" \
        " | user=#{by&.id}" \
        " | tenant=#{tenant&.id || 'global'}" \
        " | source=#{source&.id || 'all'}" \
        " | subtype=#{subtype || 'all'}"
      )
    end
  end
end
