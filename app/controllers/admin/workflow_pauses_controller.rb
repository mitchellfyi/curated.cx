# frozen_string_literal: true

module Admin
  class WorkflowPausesController < ApplicationController
    include AdminAccess

    before_action :set_workflow_pause, only: [:show, :resume]

    # GET /admin/workflow_pauses
    def index
      @active_pauses = WorkflowPause.active.recent.includes(:tenant, :source, :paused_by)
      @recent_history = WorkflowPause.resolved.recent.limit(20).includes(:tenant, :source, :paused_by, :resumed_by)
      @status_summary = WorkflowPauseService.status_summary(tenant: current_tenant_scope)
    end

    # GET /admin/workflow_pauses/:id
    def show
    end

    # POST /admin/workflow_pauses/pause
    def pause
      workflow_type = params[:workflow_type]
      tenant = params[:tenant_id].present? ? Tenant.find(params[:tenant_id]) : nil
      source = params[:source_id].present? ? Source.find(params[:source_id]) : nil
      reason = params[:reason]

      @pause = WorkflowPauseService.pause!(
        workflow_type,
        by: current_user,
        tenant: tenant,
        source: source,
        reason: reason
      )

      respond_to do |format|
        format.html { redirect_to admin_workflow_pauses_path, notice: "#{workflow_type.titleize} workflow paused successfully." }
        format.json { render json: { pause: @pause, message: "Paused successfully" } }
      end
    rescue Pundit::NotAuthorizedError => e
      respond_to do |format|
        format.html { redirect_to admin_workflow_pauses_path, alert: e.message }
        format.json { render json: { error: e.message }, status: :forbidden }
      end
    rescue ActiveRecord::RecordInvalid => e
      respond_to do |format|
        format.html { redirect_to admin_workflow_pauses_path, alert: "Failed to pause: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end

    # POST /admin/workflow_pauses/:id/resume
    def resume
      process_backlog = params[:process_backlog] == "true" || params[:process_backlog] == "1"

      WorkflowPauseService.resume!(
        @workflow_pause.workflow_type,
        by: current_user,
        tenant: @workflow_pause.tenant,
        source: @workflow_pause.source,
        process_backlog: process_backlog
      )

      respond_to do |format|
        format.html do
          notice = "Workflow resumed successfully."
          notice += " Processing backlog in background." if process_backlog
          redirect_to admin_workflow_pauses_path, notice: notice
        end
        format.json { render json: { message: "Resumed successfully", backlog_processed: process_backlog } }
      end
    rescue Pundit::NotAuthorizedError => e
      respond_to do |format|
        format.html { redirect_to admin_workflow_pauses_path, alert: e.message }
        format.json { render json: { error: e.message }, status: :forbidden }
      end
    end

    # GET /admin/workflow_pauses/backlog
    def backlog
      workflow_type = params[:workflow_type] || "editorialisation"
      tenant = params[:tenant_id].present? ? Tenant.find(params[:tenant_id]) : nil

      @backlog_size = WorkflowPauseService.backlog_size(
        workflow_type,
        tenant: tenant
      )

      render json: { workflow_type: workflow_type, backlog_size: @backlog_size }
    end

    private

    def set_workflow_pause
      @workflow_pause = WorkflowPause.find(params[:id])
    end

    def current_tenant_scope
      # Super admins can see everything, tenant admins only their tenant
      return nil if current_user.admin?

      Current.tenant
    end
  end
end
