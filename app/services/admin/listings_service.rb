# frozen_string_literal: true

module Admin
  class ListingsService
    def initialize(tenant)
      @tenant = tenant
    end

    def all_listings(category_id: nil, limit: 50)
      listings = Listing.includes(:category).recent
      listings = listings.where(category_id: category_id) if category_id.present?
      listings.limit(limit)
    end

    def find_listing(id)
      Listing.find(id)
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
