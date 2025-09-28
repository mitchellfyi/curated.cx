# frozen_string_literal: true

class TenantsController < ApplicationController
  def index
    # Only admins can list all tenants
    authorize Tenant
    @tenants = policy_scope(Tenant).includes(:categories)
  end

  def show
    authorize Current.tenant
    
    # Load recent listings for the feed
    @listings = policy_scope(Listing.includes(:category))
                    .published
                    .recent
                    .limit(20)
    
    set_page_meta_tags(
      title: Current.tenant&.title,
      description: Current.tenant&.description || t('app.tagline')
    )
  end

  def about
    authorize Current.tenant
    # Renders app/views/tenants/about.html.erb
  end
end
