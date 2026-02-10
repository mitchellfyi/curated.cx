# frozen_string_literal: true

module Admin
  class SearchController < ApplicationController
    include AdminAccess

    MIN_QUERY_LENGTH = 2
    MAX_RESULTS_PER_TYPE = 10

    # GET /admin/search
    def index
      @query = sanitize_query(params[:q])
      return if @query.blank? || @query.length < MIN_QUERY_LENGTH

      @results = perform_search
      @total = @results.values.sum(&:count)
    end

    private

    def sanitize_query(input)
      input.to_s.strip.gsub(/[%_]/, "")  # Remove LIKE wildcards from input
    end

    def perform_search
      search_pattern = "%#{@query}%"

      {
        users: search_users(search_pattern),
        content_items: search_content_items(search_pattern),
        notes: search_notes(search_pattern),
        listings: search_listings(search_pattern),
        sources: search_sources(search_pattern)
      }
    end

    def search_users(pattern)
      User.select(:id, :email, :display_name, :created_at)
          .where("email ILIKE ? OR display_name ILIKE ?", pattern, pattern)
          .order(created_at: :desc)
          .limit(MAX_RESULTS_PER_TYPE)
    end

    def search_content_items(pattern)
      Entry.feed_items.select(:id, :title, :url_canonical, :created_at)
                 .where("title ILIKE ? OR url_canonical ILIKE ?", pattern, pattern)
                 .order(created_at: :desc)
                 .limit(MAX_RESULTS_PER_TYPE)
    end

    def search_notes(pattern)
      Note.select(:id, :body, :user_id, :created_at)
          .includes(:user)
          .where("body ILIKE ?", pattern)
          .order(created_at: :desc)
          .limit(MAX_RESULTS_PER_TYPE)
    end

    def search_listings(pattern)
      Entry.directory_items.select(:id, :title, :url_canonical, :domain, :created_at)
             .where("title ILIKE ? OR url_canonical ILIKE ?", pattern, pattern)
             .order(created_at: :desc)
             .limit(MAX_RESULTS_PER_TYPE)
    end

    def search_sources(pattern)
      Source.select(:id, :name, :kind, :enabled, :created_at)
            .where("name ILIKE ?", pattern)
            .order(:name)
            .limit(MAX_RESULTS_PER_TYPE)
    end
  end
end
