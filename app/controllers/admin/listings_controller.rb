# frozen_string_literal: true

class Admin::ListingsController < ApplicationController
  include AdminAccess

  before_action :set_listing, only: %i[show edit update destroy feature unfeature extend_expiry unschedule publish_now]
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
    @listing = Listing.new
  end

  def create
    @listing = listings_service.create_listing(processed_listing_params)
    @listing.site = Current.site
    @listing.tenant = Current.tenant # Set tenant for backward compatibility

    if @listing.save
      redirect_to admin_listing_path(@listing), notice: t("admin.listings.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if listings_service.update_listing(@listing, processed_listing_params)
      redirect_to admin_listing_path(@listing), notice: t("admin.listings.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    listings_service.destroy_listing(@listing)
    redirect_to admin_listings_path, notice: t("admin.listings.deleted")
  end

  # Monetisation actions

  def feature
    @listing.update!(
      featured_from: Time.current,
      featured_until: params[:featured_until] || 30.days.from_now,
      featured_by: current_user
    )
    redirect_to admin_listing_path(@listing), notice: t("admin.listings.featured")
  end

  def unfeature
    @listing.update!(
      featured_from: nil,
      featured_until: nil,
      featured_by: nil
    )
    redirect_to admin_listing_path(@listing), notice: t("admin.listings.unfeatured")
  end

  def extend_expiry
    new_expiry = params[:expires_at] || @listing.expires_at&.+(30.days) || 30.days.from_now
    @listing.update!(expires_at: new_expiry)
    redirect_to admin_listing_path(@listing), notice: t("admin.listings.expiry_extended")
  end

  # Scheduling actions

  def unschedule
    @listing.update!(scheduled_for: nil)
    redirect_to admin_listing_path(@listing), notice: t("admin.listings.unscheduled")
  end

  def publish_now
    @listing.update!(published_at: Time.current, scheduled_for: nil)
    redirect_to admin_listing_path(@listing), notice: t("admin.listings.published_now")
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
    params.require(:listing).permit(
      :category_id, :url_raw, :title, :description,
      :image_url, :site_name, :published_at, :scheduled_for,
      :body_html, :body_text,
      # Monetisation fields
      :listing_type, :affiliate_url_template,
      :featured_from, :featured_until, :expires_at,
      :company, :location, :salary_range, :apply_url,
      :paid, :payment_reference,
      # Scheduling
      :publish_action,
      ai_summaries: {}, ai_tags: {}, metadata: {}, affiliate_attribution: {}
    )
  end

  def processed_listing_params
    attrs = listing_params.except(:publish_action)
    publish_action = params.dig(:listing, :publish_action)

    case publish_action
    when "publish"
      attrs[:published_at] = Time.current
      attrs[:scheduled_for] = nil
    when "schedule"
      attrs[:published_at] = nil
      # scheduled_for is already in attrs from the form
    when "draft"
      attrs[:published_at] = nil
      attrs[:scheduled_for] = nil
    end

    attrs
  end
end
