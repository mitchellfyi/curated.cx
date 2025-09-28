# frozen_string_literal: true

class ListingsController < ApplicationController
  before_action :check_tenant_privacy, only: [:index, :show]
  before_action :set_listing, only: [:show]
  before_action :set_category, only: [:index]

  def index
    authorize Listing
    
    @listings = if @category
                  # Category-specific listings
                  policy_scope(@category.listings.includes(:category))
                else
                  # All listings for tenant
                  policy_scope(Listing.includes(:category))
                end

    @listings = @listings.recent.limit(20)

    title = @category ? @category.name : t('listings.index.title')
    set_page_meta_tags(
      title: title,
      description: t('listings.index.description', 
                    category: @category&.name || 'all categories',
                    tenant: Current.tenant&.title)
    )
  end

  def show
    authorize @listing
    
    set_page_meta_tags(
      title: @listing.title,
      description: @listing.description,
      canonical: @listing.url_canonical,
      og: {
        title: @listing.title,
        description: @listing.description,
        image: @listing.image_url,
        url: listing_url(@listing)
      }
    )
  end

  private

  def set_listing
    @listing = policy_scope(Listing).includes(:category, :tenant).find(params[:id])
  end

  def set_category
    @category = policy_scope(Category).includes(:tenant).find(params[:category_id]) if params[:category_id].present?
  end
end
