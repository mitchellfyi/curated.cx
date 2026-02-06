# frozen_string_literal: true

module Admin
  class TenantSettingsController < ApplicationController
    include AdminAccess

    before_action :require_owner_access
    before_action :set_tenant

    def show
      @sites = @tenant.sites.includes(:domains)
      @domains = Domain.joins(:site).where(sites: { tenant_id: @tenant.id })
    end

    def update
      @tenant.assign_attributes(tenant_column_params)
      apply_settings_params

      if @tenant.save
        redirect_to admin_tenant_settings_path, notice: "Settings updated successfully."
      else
        @sites = @tenant.sites.includes(:domains)
        @domains = Domain.joins(:site).where(sites: { tenant_id: @tenant.id })
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_tenant
      @tenant = Current.tenant
    end

    def require_owner_access
      return if current_user&.admin?
      return if Current.tenant && current_user&.has_role?(:owner, Current.tenant)

      redirect_to admin_root_path, alert: "Only tenant owners can access settings."
    end

    def tenant_column_params
      params.require(:tenant).permit(:title, :hostname, :logo_url)
    end

    def apply_settings_params
      settings_fields = params.require(:tenant).permit(
        :favicon_url, :meta_title, :meta_description,
        :twitter_handle, :analytics_id,
        :custom_css, :custom_head_html
      )

      new_settings = @tenant.settings.deep_dup
      settings_fields.each do |key, value|
        new_settings[key] = value
      end
      @tenant.settings = new_settings
    end
  end
end
