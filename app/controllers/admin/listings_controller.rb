# frozen_string_literal: true

class Admin::ListingsController < ApplicationController
  before_action :set_listing, only: [ :show, :edit, :update, :destroy ]
  before_action :ensure_admin_access
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    @listings = Listing.where(tenant: Current.tenant).includes(:category).recent
    @listings = @listings.where(category_id: params[:category_id]) if params[:category_id].present?
    @listings = @listings.limit(50) # Simple pagination for now
    @categories = Category.where(tenant: Current.tenant).order(:name)
  end

  def show
  end

  def new
    @listing = Listing.new
    @categories = Category.where(tenant: Current.tenant).order(:name)
  end

  def create
    @listing = Listing.new(listing_params)
    @listing.tenant = Current.tenant

    if @listing.save
      redirect_to admin_listing_path(@listing), notice: t("admin.listings.created")
    else
      @categories = Category.where(tenant: Current.tenant).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Category.where(tenant: Current.tenant).order(:name)
  end

  def update
    if @listing.update(listing_params)
      redirect_to admin_listing_path(@listing), notice: t("admin.listings.updated")
    else
      @categories = Category.where(tenant: Current.tenant).order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @listing.destroy
    redirect_to admin_listings_path, notice: t("admin.listings.deleted")
  end

  private

  def set_listing
    @listing = Listing.where(tenant: Current.tenant).find(params[:id])
  end

  def listing_params
    params.require(:listing).permit(:category_id, :url_raw, :title, :description,
                                   :image_url, :site_name, :published_at,
                                   :body_html, :body_text,
                                   ai_summaries: {}, ai_tags: {}, metadata: {})
  end

  def ensure_admin_access
    unless current_user&.admin? || (Current.tenant && current_user&.has_role?(:owner, Current.tenant))
      flash[:alert] = "Access denied. Admin privileges required."
      redirect_to root_path
    end
  end
end
