# frozen_string_literal: true

class SearchController < ApplicationController
  # Skip policy scope since we manually filter by site and use custom search logic
  skip_after_action :verify_policy_scoped

  PER_PAGE = 20
  MIN_QUERY_LENGTH = 2

  def index
    authorize :search, :index?

    @query = search_params[:q].to_s.strip
    @type_filter = search_params[:type]

    if @query.length >= MIN_QUERY_LENGTH
      perform_search
    else
      @content_items = []
      @listings = []
      @entries = []
      @total_count = 0
    end

    set_search_meta_tags
  end

  private

  def search_params
    params.permit(:q, :type, :page)
  end

  def perform_search
    case @type_filter
    when "content"
      @content_items = search_content_items
      @listings = []
    when "listings", "entries"
      @content_items = []
      @listings = search_listings
    else
      @content_items = search_content_items
      @listings = search_listings
    end

    @entries = Array(@content_items) + Array(@listings)
    @total_count = @entries.size
  end

  def search_content_items
    Entry.feed_items
      .where(site: Current.site)
      .published
      .not_hidden
      .search_content(@query)
      .limit(PER_PAGE)
  end

  def search_listings
    Entry.directory_items
      .where(site: Current.site)
      .published
      .search_content(@query)
      .limit(PER_PAGE)
  end

  def set_search_meta_tags
    set_page_meta_tags(
      title: @query.present? ? t("search.results_title", query: @query) : t("search.title"),
      description: t("search.description"),
      robots: "noindex, follow"
    )
  end
end
