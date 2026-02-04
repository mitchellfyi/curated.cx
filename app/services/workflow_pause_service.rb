# frozen_string_literal: true

# Service for managing workflow pauses.
# Provides a clean API for pausing/resuming workflows and checking pause status.
#
# Usage:
#   # Check if paused
#   WorkflowPauseService.paused?(:rss_ingestion, tenant: tenant)
#
#   # Pause a workflow
#   WorkflowPauseService.pause!(:editorialisation, by: user, tenant: tenant, reason: "Cost control")
#
#   # Resume a workflow
#   WorkflowPauseService.resume!(:editorialisation, by: user, tenant: tenant, process_backlog: true)
#
#   # Get backlog size
#   WorkflowPauseService.backlog_size(:editorialisation, tenant: tenant)
#
class WorkflowPauseService
  class << self
    # Check if a workflow is currently paused
    # Returns true if any applicable pause exists (global, tenant, or source level)
    def paused?(workflow_type, tenant: nil, source: nil)
      workflow_type = normalize_workflow_type(workflow_type)
      WorkflowPause.paused?(workflow_type, tenant: tenant, source: source)
    end

    # Pause a workflow
    # @param workflow_type [Symbol, String] The type of workflow to pause
    # @param by [User] The user pausing the workflow
    # @param tenant [Tenant, nil] The tenant to pause for (nil = global)
    # @param source [Source, nil] The specific source to pause
    # @param reason [String, nil] Optional reason for the pause
    # @return [WorkflowPause] The created pause record
    def pause!(workflow_type, by:, tenant: nil, source: nil, reason: nil)
      workflow_type = normalize_workflow_type(workflow_type)

      # Validate permissions
      validate_pause_permissions!(by, tenant: tenant, source: source)

      # Check if already paused at this level
      existing = WorkflowPause.active
                              .for_workflow(workflow_type)
                              .where(tenant: tenant, source: source)
                              .first

      return existing if existing

      WorkflowPause.create!(
        workflow_type: workflow_type,
        tenant: tenant,
        source: source,
        paused_by: by,
        paused_at: Time.current,
        reason: reason
      )
    end

    # Resume a workflow
    # @param workflow_type [Symbol, String] The type of workflow to resume
    # @param by [User] The user resuming the workflow
    # @param tenant [Tenant, nil] The tenant to resume for (nil = global)
    # @param source [Source, nil] The specific source to resume
    # @param process_backlog [Boolean] Whether to process accumulated backlog
    # @return [WorkflowPause, nil] The resumed pause record, or nil if not paused
    def resume!(workflow_type, by:, tenant: nil, source: nil, process_backlog: false)
      workflow_type = normalize_workflow_type(workflow_type)

      # Validate permissions
      validate_pause_permissions!(by, tenant: tenant, source: source)

      # Find active pause at this exact level
      pause = WorkflowPause.active
                           .for_workflow(workflow_type)
                           .where(tenant: tenant, source: source)
                           .first

      return nil unless pause

      pause.resume!(by: by)

      # Process backlog if requested
      process_workflow_backlog(workflow_type, tenant: tenant, source: source) if process_backlog

      pause
    end

    # Get the size of the backlog for a paused workflow
    def backlog_size(workflow_type, tenant: nil, source: nil)
      workflow_type = normalize_workflow_type(workflow_type)

      case workflow_type
      when "editorialisation"
        editorialisation_backlog_size(tenant: tenant, source: source)
      when "rss_ingestion", "serp_api_ingestion", "all_ingestion"
        ingestion_backlog_size(workflow_type, tenant: tenant, source: source)
      else
        0
      end
    end

    # Get all active pauses, optionally filtered
    def active_pauses(tenant: nil, include_global: true)
      pauses = WorkflowPause.active.recent

      if tenant
        pauses = pauses.where(tenant: [tenant, nil])
      elsif !include_global
        pauses = pauses.where.not(tenant_id: nil)
      end

      pauses
    end

    # Get pause status summary for admin UI
    def status_summary(tenant: nil)
      pauses = active_pauses(tenant: tenant)

      {
        total_active: pauses.count,
        by_workflow: pauses.group(:workflow_type).count,
        global_pauses: pauses.global.count,
        tenant_pauses: pauses.where.not(tenant_id: nil).count,
        oldest_pause: pauses.order(:paused_at).first,
        backlogs: WorkflowPause::WORKFLOW_TYPES.index_with do |type|
          backlog_size(type, tenant: tenant)
        end
      }
    end

    private

    def normalize_workflow_type(type)
      type.to_s.underscore
    end

    def validate_pause_permissions!(user, tenant:, source:)
      # Super admin can do anything
      return if user.admin?

      # Global pauses require super admin
      if tenant.nil? && source.nil?
        raise Pundit::NotAuthorizedError, "Only super admins can create global pauses"
      end

      # Tenant admin can pause their own tenant
      if tenant && user.has_role?(:admin, tenant)
        # If source specified, verify it belongs to tenant
        if source && source.tenant_id != tenant.id
          raise Pundit::NotAuthorizedError, "Source does not belong to this tenant"
        end
        return
      end

      raise Pundit::NotAuthorizedError, "You don't have permission to pause this workflow"
    end

    def editorialisation_backlog_size(tenant:, source:)
      scope = ContentItem.published.where(editorialised_at: nil)

      if source
        scope = scope.where(source: source)
      elsif tenant
        scope = scope.joins(:site).where(sites: { tenant_id: tenant.id })
      end

      # Only count items from sources with editorialisation enabled
      scope.joins(:source)
           .where(sources: { config: {} }) # This needs to check editorialisation_enabled
           .or(
             scope.joins(:source).where("sources.config->>'editorialise' = 'true'")
           )
           .count
    end

    def ingestion_backlog_size(workflow_type, tenant:, source:)
      scope = Source.enabled

      case workflow_type
      when "rss_ingestion"
        scope = scope.where(kind: :rss)
      when "serp_api_ingestion"
        scope = scope.where(kind: [:serp_api_google_news, :serp_api_google_jobs, :serp_api_youtube])
      end

      if source
        scope = scope.where(id: source.id)
      elsif tenant
        scope = scope.joins(:site).where(sites: { tenant_id: tenant.id })
      end

      # Count sources that are due for a run
      scope.due_for_run.count
    end

    def process_workflow_backlog(workflow_type, tenant:, source:)
      case workflow_type
      when "editorialisation"
        process_editorialisation_backlog(tenant: tenant, source: source)
      when "rss_ingestion"
        process_ingestion_backlog(:rss, tenant: tenant, source: source)
      when "serp_api_ingestion"
        process_ingestion_backlog(:serp_api, tenant: tenant, source: source)
      when "all_ingestion"
        process_ingestion_backlog(:all, tenant: tenant, source: source)
      end
    end

    def process_editorialisation_backlog(tenant:, source:)
      scope = ContentItem.published.where(editorialised_at: nil)

      if source
        scope = scope.where(source: source)
      elsif tenant
        scope = scope.joins(:site).where(sites: { tenant_id: tenant.id })
      end

      # Only process items from sources with editorialisation enabled
      scope = scope.joins(:source)
                   .where("sources.config->>'editorialise' = 'true'")
                   .limit(100) # Process in batches

      scope.find_each do |content_item|
        EditorialiseContentItemJob.perform_later(content_item.id)
      end
    end

    def process_ingestion_backlog(kind, tenant:, source:)
      scope = Source.enabled.due_for_run

      case kind
      when :rss
        scope = scope.where(kind: :rss)
      when :serp_api
        scope = scope.where(kind: [:serp_api_google_news, :serp_api_google_jobs, :serp_api_youtube])
      end

      if source
        scope = scope.where(id: source.id)
      elsif tenant
        scope = scope.joins(:site).where(sites: { tenant_id: tenant.id })
      end

      scope.find_each do |src|
        case src.kind
        when "rss"
          FetchRssJob.perform_later(src.id)
        when "serp_api_google_news"
          SerpApiIngestionJob.perform_later(src.id)
        when "serp_api_google_jobs"
          SerpApiJobsIngestionJob.perform_later(src.id)
        when "serp_api_youtube"
          SerpApiYoutubeIngestionJob.perform_later(src.id)
        end
      end
    end
  end
end
