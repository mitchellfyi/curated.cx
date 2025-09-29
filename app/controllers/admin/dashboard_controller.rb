# frozen_string_literal: true

class Admin::DashboardController < ApplicationController
  include AdminAccess

  def index
    @tenant = Current.tenant.decorate
    @categories = Category.where(tenant: Current.tenant).includes(:listings)
    @recent_listings = Listing.where(tenant: Current.tenant).includes(:category).recent.limit(10)
    @stats = {
      total_categories: @categories.count,
      total_listings: Listing.where(tenant: Current.tenant).count,
      published_listings: Listing.where(tenant: Current.tenant).published.count,
      listings_today: Listing.where(tenant: Current.tenant, created_at: Time.current.beginning_of_day..Time.current.end_of_day).count
    }

    set_page_meta_tags(
      title: t("admin.dashboard.title"),
      description: t("admin.dashboard.description", tenant: @tenant.title)
    )
  end

  private
end
