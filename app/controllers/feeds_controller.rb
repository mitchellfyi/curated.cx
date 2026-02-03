# frozen_string_literal: true

# Controller for RSS and Atom feed endpoints.
# Provides syndication feeds for content discovery and subscription.
#
# Available feeds:
# - /feeds/rss (or .atom) - Main content feed
# - /feeds/listings.rss - Listings feed
# - /feeds/categories/:id.rss - Category-specific listings feed
class FeedsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  MAX_ITEMS = 50

  def content
    @content_items = content_items_for_feed

    respond_to do |format|
      format.rss { render :content_rss, formats: [ :rss ] }
      format.atom { render :content_atom, formats: [ :atom ] }
    end
  end

  def listings
    @listings = listings_for_feed

    respond_to do |format|
      format.rss { render :listings_rss, formats: [ :rss ] }
      format.atom { render :listings_atom, formats: [ :atom ] }
    end
  end

  def category
    @category = Category.find(params[:id])
    @listings = listings_for_category(@category)

    respond_to do |format|
      format.rss { render :category_rss, formats: [ :rss ] }
      format.atom { render :category_atom, formats: [ :atom ] }
    end
  end

  private

  def content_items_for_feed
    ContentItem
      
      .published
      .not_hidden
      .order(published_at: :desc)
      .limit(MAX_ITEMS)
  end

  def listings_for_feed
    Listing
      
      .published
      .not_expired
      .order(published_at: :desc)
      .includes(:category)
      .limit(MAX_ITEMS)
  end

  def listings_for_category(category)
    category.listings
            .published
            .not_expired
            .order(published_at: :desc)
            .limit(MAX_ITEMS)
  end
end
