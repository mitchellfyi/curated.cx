# frozen_string_literal: true

module Admin
  class TenantsController < ApplicationController
    include AdminAccess

    before_action :require_super_admin
    before_action :set_tenant, only: [ :show, :edit, :update, :destroy, :impersonate ]

    # GET /admin/tenants
    def index
      @tenants = Tenant.includes(:sites).order(:title)

      if params[:search].present?
        @tenants = @tenants.where("title ILIKE ? OR slug ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
      end

      @stats = build_stats
      @tenant_metrics = build_tenant_metrics
    end

    # GET /admin/tenants/:id
    def show
      @sites = @tenant.sites.includes(:domains)
      @recent_listings = Listing.where(site: @sites).recent.limit(10)
      @users_count = User.joins(:roles).where(roles: { resource: @tenant }).distinct.count
    end

    # GET /admin/tenants/:id/edit
    def edit
    end

    # PATCH /admin/tenants/:id
    def update
      if @tenant.update(tenant_params)
        redirect_to admin_tenant_path(@tenant), notice: "Tenant updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/tenants/:id
    def destroy
      if @tenant.sites.any?
        redirect_to admin_tenant_path(@tenant), alert: "Cannot delete tenant with active sites."
      else
        @tenant.destroy
        redirect_to admin_tenants_path, notice: "Tenant deleted."
      end
    end

    # POST /admin/tenants/:id/impersonate
    def impersonate
      session[:admin_impersonating_tenant] = @tenant.id
      redirect_to root_url(host: @tenant.primary_hostname), notice: "Now viewing as #{@tenant.title}"
    end

    private

    def require_super_admin
      unless current_user&.admin?
        redirect_to admin_root_path, alert: "Super admin access required."
      end
    end

    def set_tenant
      @tenant = Tenant.find(params[:id])
    end

    def tenant_params
      params.require(:tenant).permit(
        :title, :slug, :hostname, :logo_url, :description,
        settings: {}
      )
    end

    def build_stats
      {
        total_tenants: Tenant.count,
        total_sites: Site.count,
        total_listings: Listing.count,
        total_users: User.count,
        active_sources: Source.enabled.count,
        failed_imports_today: ImportRun.failed.where("started_at > ?", Time.current.beginning_of_day).count,
        active_pauses: WorkflowPause.active.count
      }
    end

    def build_tenant_metrics
      # Pre-load per-tenant counts for index display
      site_counts = Site.group(:tenant_id).count
      listing_counts = Listing.joins(:site).group("sites.tenant_id").count
      source_counts = Source.enabled.joins(:site).group("sites.tenant_id").count
      failed_import_counts = ImportRun.failed
                                       .where("started_at > ?", Time.current.beginning_of_day)
                                       .joins(source: :site)
                                       .group("sites.tenant_id").count

      @tenants.each_with_object({}) do |tenant, hash|
        hash[tenant.id] = {
          sites: site_counts[tenant.id] || 0,
          listings: listing_counts[tenant.id] || 0,
          sources: source_counts[tenant.id] || 0,
          failed_imports: failed_import_counts[tenant.id] || 0
        }
      end
    end
  end
end
