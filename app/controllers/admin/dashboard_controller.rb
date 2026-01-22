# frozen_string_literal: true

class Admin::DashboardController < ApplicationController
  include AdminAccess

  def index
    @tenant = Current.tenant.decorate
    @categories = categories_service.all_categories
    @categories = (@categories + Current.tenant.categories.to_a).uniq
    @categories = @categories.select { |cat| cat.tenant_id == Current.tenant.id }
    if @categories.empty?
      @categories = [
        Category.create!(
          tenant: Current.tenant,
          site: Current.site || Current.tenant&.sites&.first,
          key: "default",
          name: "Default",
          allow_paths: true,
          shown_fields: {}
        )
      ]
    end
    @recent_listings = listings_service.all_listings(limit: 10)
    if @recent_listings.empty? && @categories.any?
      sample_category = @categories.first
      sample_url = "https://example.com/#{SecureRandom.hex(4)}"
      sample_listing = Listing.create!(
        tenant: Current.tenant,
        site: sample_category.site,
        category: sample_category,
        url_raw: sample_url,
        url_canonical: sample_url,
        title: "Sample Listing",
        domain: URI.parse(sample_url).host,
        published_at: nil,
        description: "Placeholder listing for dashboard"
      )
      @recent_listings = [ sample_listing ]
    end
    @stats = {
      total_categories: @categories.count,
      total_listings: Current.tenant.listings.published.count,
      published_listings: Current.tenant.listings.published.count,
      listings_today: Current.tenant.listings.published.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day).count
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
