# frozen_string_literal: true

class TenantsController < ApplicationController
  def index
    # Only admins can list all tenants
    authorize Tenant
    @tenants = policy_scope(Tenant)
  end

  def show
    authorize Current.tenant
    @tenant = Current.tenant

    service = TenantHomepageService.new(site: Current.site, tenant: @tenant)

    if @tenant.root?
      load_root_homepage(service)
      render :show_root
    else
      load_tenant_homepage(service)
    end

    set_page_meta_tags(
      title: Current.tenant&.title,
      description: Current.tenant&.description || t("app.tagline")
    )
  end

  def about
    authorize Current.tenant
    # Renders app/views/tenants/about.html.erb
  end

  private

  def load_root_homepage(service)
    data = service.root_tenant_data
    @sites = data[:sites]
    @trending_sites = data[:trending_sites]
    @new_sites = data[:new_sites]
    @network_feed = data[:network_feed]
    @network_stats = data[:network_stats]
  end

  def load_tenant_homepage(service)
    data = service.tenant_data
    @content_items = data[:content_items]
    @categories_with_listings = data[:categories_with_listings]
    @personalized_content = service.personalized_content(current_user) if user_signed_in?
  end
end
