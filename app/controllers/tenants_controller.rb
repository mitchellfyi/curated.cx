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

    # Load ranked content feed for the homepage
    @content_items = FeedRankingService.ranked_feed(
      site: Current.site,
      filters: {},
      limit: 12,
      offset: 0
    )

    set_page_meta_tags(
      title: Current.tenant&.title,
      description: Current.tenant&.description || t("app.tagline")
    )
  end

  def about
    authorize Current.tenant
    # Renders app/views/tenants/about.html.erb
  end
end
