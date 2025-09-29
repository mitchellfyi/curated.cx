# frozen_string_literal: true

class Admin::ListingsController < ApplicationController
  include AdminAccess

  before_action :set_listing, only: [ :show, :edit, :update, :destroy ]
  before_action :set_categories

  def index
    @listings = listings_service.all_listings(
      category_id: params[:category_id],
      limit: 50
    )
  end

  def show
  end

  def new
    @listing = listings_service.create_listing(listing_params)
  end

  def create
    @listing = listings_service.create_listing(listing_params)
    @listing.tenant = Current.tenant

    if @listing.save
      redirect_to admin_listing_path(@listing), notice: t("admin.listings.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if listings_service.update_listing(@listing, listing_params)
      redirect_to admin_listing_path(@listing), notice: t("admin.listings.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    listings_service.destroy_listing(@listing)
    redirect_to admin_listings_path, notice: t("admin.listings.deleted")
  end

  private

  def set_listing
    @listing = listings_service.find_listing(params[:id])
  end

  def set_categories
    @categories = categories_service.all_categories
  end

  def listings_service
    @listings_service ||= Admin::ListingsService.new(Current.tenant)
  end

  def categories_service
    @categories_service ||= Admin::CategoriesService.new(Current.tenant)
  end

  def listing_params
    params.require(:listing).permit(:category_id, :url_raw, :title, :description,
                                   :image_url, :site_name, :published_at,
                                   :body_html, :body_text,
                                   ai_summaries: {}, ai_tags: {}, metadata: {})
  end
end
