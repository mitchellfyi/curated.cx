# frozen_string_literal: true

class Admin::DashboardController < ApplicationController
  include AdminAccess

  def index
    @tenant = Current.tenant.decorate
    @categories = categories_service.all_categories
    @recent_listings = listings_service.all_listings(limit: 10)
    @stats = {
      total_categories: @categories.count,
      total_listings: Current.tenant.listings.count,
      published_listings: Current.tenant.listings.published.count,
      listings_today: Current.tenant.listings.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day).count
    }

    set_page_meta_tags(
      title: t("admin.dashboard.title"),
      description: t("admin.dashboard.description", tenant: @tenant.title)
    )
  end

  private

  def categories_service
    @categories_service ||= Admin::CategoriesService.new(Current.tenant)
  end

  def listings_service
    @listings_service ||= Admin::ListingsService.new(Current.tenant)
  end
end
