# frozen_string_literal: true

module Admin
  class WorkflowPausesController < ApplicationController
    include AdminAccess

    before_action :require_admin_for_global, only: [:create, :destroy]

    # GET /admin/workflow_pauses
    def index
      @pauses = WorkflowPause.active.order(created_at: :desc)
      @status = WorkflowPauseService.status_summary(tenant: current_tenant_for_pause)
      @import_backlog = WorkflowPauseService.backlog_size(:imports, tenant: current_tenant_for_pause)
      @ai_backlog = WorkflowPauseService.backlog_size(:ai_processing, tenant: current_tenant_for_pause)
    end

    # POST /admin/workflow_pauses
    def create
      tenant = params[:global] == "true" ? nil : Current.tenant
      
      pause = WorkflowPauseService.pause!(
        params[:workflow_type],
        by: current_user,
        tenant: tenant,
        subtype: params[:subtype].presence,
        reason: params[:reason]
      )

      respond_to do |format|
        format.html { redirect_to admin_workflow_pauses_path, notice: "Workflow paused successfully" }
        format.json { render json: pause }
      end
    rescue ArgumentError => e
      respond_to do |format|
        format.html { redirect_to admin_workflow_pauses_path, alert: e.message }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end

    # DELETE /admin/workflow_pauses/:id
    def destroy
      pause = WorkflowPause.find(params[:id])
      
      # Check authorization
      unless current_user.admin? || pause.tenant == Current.tenant
        raise Pundit::NotAuthorizedError, "Cannot resume this pause"
      end

      WorkflowPauseService.resume!(
        pause.workflow_type,
        by: current_user,
        tenant: pause.tenant,
        subtype: pause.workflow_subtype,
        source: pause.source,
        process_backlog: params[:process_backlog] != "false"
      )

      respond_to do |format|
        format.html { redirect_to admin_workflow_pauses_path, notice: "Workflow resumed successfully" }
        format.json { render json: { success: true } }
      end
    end

    private

    def require_admin_for_global
      if params[:global] == "true" && !current_user.admin?
        raise Pundit::NotAuthorizedError, "Only super admins can pause globally"
      end
    end

    def current_tenant_for_pause
      current_user.admin? ? nil : Current.tenant
    end
  end
end
