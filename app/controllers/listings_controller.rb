# frozen_string_literal: true

class ListingsController < ApplicationController
  before_action :check_tenant_privacy, only: [ :index, :show ]
  before_action :set_listing, only: [ :show ]
  before_action :set_category, only: [ :index ]

  def index
    authorize Listing

    # Get featured listings for the featured section (unfiltered)
    @featured_listings = policy_scope(Listing.includes(:category))
                          .featured
                          .not_expired
                          .published_recent
                          .limit(3)

    # Build filtered listings query
    base_scope = @category ? @category.listings : Listing
    @listings = policy_scope(base_scope.includes(:category))
                  .not_expired
                  .published
                  .filtered(filter_params)
                  .recent
                  .limit(50)

    # Get categories for filter dropdown
    @categories = policy_scope(Category).order(:name)

    # Get counts for listing types
    @type_counts = policy_scope(Listing)
                     .not_expired
                     .published
                     .group(:listing_type)
                     .count

    # Store current filters for view
    @current_filters = filter_params

    title = @category ? @category.name : t("listings.index.title")
    set_page_meta_tags(
      title: title,
      description: t("listings.index.description",
                    category: @category&.name || t("nav.all_categories"),
                    tenant: Current.tenant&.title)
    )

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    authorize @listing

    set_listing_meta_tags(@listing)
    set_canonical_url(params: [])
  end

  private

  def set_listing
    @listing = policy_scope(Listing).includes(:category, :tenant).find(params[:id])
  end

  def set_category
    @category = policy_scope(Category).includes(:tenant).find(params[:category_id]) if params[:category_id].present?
  end

  def filter_params
    params.permit(:q, :type, :category_id, :freshness).to_h.symbolize_keys
  end
end
