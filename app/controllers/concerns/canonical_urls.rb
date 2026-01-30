# frozen_string_literal: true

# Concern for managing canonical URLs and pagination link tags.
#
# Provides methods for:
# - Setting proper canonical URLs that exclude ephemeral params (sort, page)
# - Adding rel=prev/next pagination links for SEO
# - Supporting custom canonical overrides
#
# Usage:
#   include CanonicalUrls
#
#   def index
#     set_canonical_url(params: [:category_id]) # Include only specific params
#     set_pagination_links(current_page: 2, total_pages: 10)
#   end
module CanonicalUrls
  extend ActiveSupport::Concern

  # Parameters that should be excluded from canonical URLs
  # These represent ephemeral state, not unique content
  EXCLUDED_PARAMS = %w[
    page
    sort
    order
    direction
    utm_source
    utm_medium
    utm_campaign
    utm_term
    utm_content
    ref
    source
    fbclid
    gclid
    mc_cid
    mc_eid
  ].freeze

  included do
    helper_method :canonical_url if respond_to?(:helper_method)
    helper_method :pagination_links if respond_to?(:helper_method)
  end

  # Set the canonical URL for the current page
  #
  # @param url [String, nil] Custom canonical URL (optional)
  # @param params [Array<Symbol>, nil] List of params to include (nil = all non-excluded)
  # @param include_page [Boolean] Whether to include page param (default: false)
  def set_canonical_url(url: nil, params: nil, include_page: false)
    @_canonical_url = url || build_canonical_url(
      allowed_params: params,
      include_page: include_page
    )

    # Update the meta tags
    set_meta_tags(canonical: @_canonical_url)
  end

  # Set rel=prev/next pagination links
  #
  # @param current_page [Integer] Current page number (1-based)
  # @param total_pages [Integer] Total number of pages
  # @param per_page [Integer] Items per page (for calculation if total_pages not provided)
  # @param total_count [Integer] Total item count (alternative to total_pages)
  # @param base_params [Hash] Additional params to include in pagination URLs
  def set_pagination_links(current_page:, total_pages: nil, per_page: nil, total_count: nil, base_params: {})
    current_page = [ current_page.to_i, 1 ].max

    # Calculate total pages if not provided
    if total_pages.nil? && total_count && per_page
      total_pages = (total_count.to_f / per_page).ceil
    end

    @_pagination_links = {}

    # Build base URL without page param
    base_url_params = request.query_parameters
                             .except(*EXCLUDED_PARAMS.map(&:to_s))
                             .merge(base_params.stringify_keys)

    # Set prev link if not on first page
    if current_page > 1
      prev_page = current_page - 1
      prev_params = prev_page > 1 ? base_url_params.merge("page" => prev_page) : base_url_params
      @_pagination_links[:prev] = build_absolute_url(prev_params)
    end

    # Set next link if not on last page
    if total_pages.nil? || current_page < total_pages
      next_params = base_url_params.merge("page" => current_page + 1)
      @_pagination_links[:next] = build_absolute_url(next_params)
    end

    # Set the pagination meta tags
    set_pagination_meta_tags
  end

  # Get the canonical URL for the current page
  def canonical_url
    @_canonical_url || build_canonical_url
  end

  # Get pagination links hash
  def pagination_links
    @_pagination_links || {}
  end

  private

  def build_canonical_url(allowed_params: nil, include_page: false)
    # Get current query params
    current_params = request.query_parameters.dup

    # Filter out excluded params
    excluded = EXCLUDED_PARAMS.dup
    excluded -= [ "page" ] if include_page
    current_params = current_params.except(*excluded.map(&:to_s))

    # If allowed_params specified, only include those
    if allowed_params.present?
      allowed_keys = allowed_params.map(&:to_s)
      current_params = current_params.slice(*allowed_keys)
    end

    build_absolute_url(current_params)
  end

  def build_absolute_url(params = {})
    return tenant_absolute_url(request.path) if params.blank?

    query_string = params.to_query
    path_with_query = query_string.present? ? "#{request.path}?#{query_string}" : request.path
    tenant_absolute_url(path_with_query)
  end

  def tenant_absolute_url(path)
    return path unless Current.tenant

    Current.tenant.decorate.absolute_url(path)
  end

  def set_pagination_meta_tags
    return if @_pagination_links.blank?

    # The meta-tags gem supports prev/next via the index parameter
    # We need to set them in a format that will be rendered as link tags
    if @_pagination_links[:prev]
      set_meta_tags(prev: @_pagination_links[:prev])
    end

    if @_pagination_links[:next]
      set_meta_tags(next: @_pagination_links[:next])
    end
  end
end
