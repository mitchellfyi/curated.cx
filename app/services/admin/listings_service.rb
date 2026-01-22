# frozen_string_literal: true

module Admin
  class ListingsService
    def initialize(tenant)
      @tenant = tenant
    end

    def all_listings(category_id: nil, limit: 50)
      target_tenant = @tenant || Current.tenant
      scope = Listing.without_site_scope.includes(:category)
      scope = scope.where(tenant: target_tenant) if target_tenant
      active_site = Current.site || target_tenant&.sites&.first
      scope = scope.where(site: active_site) if active_site
      scope = scope.where(category_id: category_id) if category_id
      scope = scope.where.not(category_id: nil)
      scope.order(created_at: :desc).limit(limit)
    end

    def find_listing(id)
      Listing.includes(:category, :tenant).find(id)
    end

    def create_listing(attributes)
      Listing.new(attributes)
    end

    def update_listing(listing, attributes)
      listing.update(attributes)
    end

    def destroy_listing(listing)
      listing.destroy
    end
  end
end
