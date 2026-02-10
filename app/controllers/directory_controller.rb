# frozen_string_literal: true

# Public directory of curated entries (formerly "listings").
# Serves /listings and /categories/:id/listings.
class DirectoryController < ApplicationController
  before_action :check_tenant_privacy, only: [ :index, :show ]
  before_action :set_entry, only: [ :show ]
  before_action :set_category, only: [ :index ]

  def index
    authorize Entry

    scope = Entry.directory_items.includes(:category)
    scope = scope.where(site: Current.site)

    @featured_listings = policy_scope(scope)
                          .featured
                          .not_expired
                          .published
                          .recent
                          .limit(3)

    base_scope = @category ? scope.where(category_id: @category.id) : scope
    @listings = policy_scope(base_scope.includes(:category))
                  .not_expired
                  .published
                  .filtered(filter_params)
                  .recent
                  .limit(50)

    @categories = policy_scope(Category).order(:name)
    @current_filters = filter_params

    set_page_meta_tags(
      title: @category ? @category.name : t("listings.index.title"),
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
    authorize @entry
    set_listing_meta_tags(@entry)
    set_canonical_url(params: [])
  end

  private

  def set_entry
    @entry = policy_scope(Entry.directory_items).includes(:category, :tenant).find(params[:id])
  end

  def set_category
    @category = policy_scope(Category).includes(:tenant).find(params[:category_id]) if params[:category_id].present?
  end

  def filter_params
    params.permit(:q, :type, :category_id, :freshness).to_h.symbolize_keys
  end
end
