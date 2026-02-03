# frozen_string_literal: true

module Admin
  class SearchController < ApplicationController
    include AdminAccess

    # GET /admin/search
    def index
      @query = params[:q].to_s.strip
      return unless @query.present?

      @results = {
        users: search_users,
        content_items: search_content_items,
        notes: search_notes,
        listings: search_listings,
        sources: search_sources
      }

      @total = @results.values.sum(&:count)
    end

    private

    def search_users
      User.where("email ILIKE ? OR display_name ILIKE ?", "%#{@query}%", "%#{@query}%")
          .limit(10)
    end

    def search_content_items
      ContentItem.where("title ILIKE ? OR url_canonical ILIKE ?", "%#{@query}%", "%#{@query}%")
                 .order(created_at: :desc)
                 .limit(10)
    end

    def search_notes
      Note.where("body ILIKE ?", "%#{@query}%")
          .order(created_at: :desc)
          .limit(10)
    end

    def search_listings
      Listing.where("title ILIKE ? OR url_canonical ILIKE ?", "%#{@query}%", "%#{@query}%")
             .order(created_at: :desc)
             .limit(10)
    end

    def search_sources
      Source.where("name ILIKE ?", "%#{@query}%")
            .order(:name)
            .limit(10)
    end
  end
end
