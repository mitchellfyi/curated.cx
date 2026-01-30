# frozen_string_literal: true

class FeedController < ApplicationController
  # Skip policy scope verification since we manually scope by Current.site
  # and use FeedRankingService for content filtering
  skip_after_action :verify_policy_scoped

  PER_PAGE = 20
  MAX_RSS_ITEMS = 50

  def index
    authorize ContentItem, :index?

    @content_items = FeedRankingService.ranked_feed(
      site: Current.site,
      filters: feed_filters,
      limit: PER_PAGE,
      offset: page_offset
    )

    @taxonomies = Taxonomy.where(site: Current.site).roots.by_position
    @content_types = content_types_for_site

    set_feed_meta_tags
    set_feed_canonical_and_pagination
  end

  def rss
    authorize ContentItem, :index?

    @content_items = FeedRankingService.ranked_feed(
      site: Current.site,
      filters: { sort: "latest" },
      limit: MAX_RSS_ITEMS,
      offset: 0
    )

    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  private

  def feed_filters
    {
      tag: params[:tag],
      content_type: params[:content_type],
      sort: params[:sort]
    }.compact_blank
  end

  def page_offset
    page = [ params[:page].to_i, 1 ].max
    (page - 1) * PER_PAGE
  end

  def content_types_for_site
    ContentItem.where(site: Current.site)
               .published
               .distinct
               .pluck(:content_type)
               .compact
               .sort
  end

  def set_feed_meta_tags
    tenant = Current.tenant&.decorate

    set_social_meta_tags(
      title: t("feed.index.title", site: tenant&.title),
      description: t("feed.index.description", site: tenant&.title),
      url: feed_index_url,
      type: "website"
    )
    set_meta_tags(alternate: { "application/rss+xml" => feed_rss_url })
  end

  def set_feed_canonical_and_pagination
    # Canonical URL includes filter params (tag, content_type) but not sort/page
    # This follows Google's recommendation for self-referencing canonicals on filtered views
    set_canonical_url(params: %i[tag content_type])

    # Set pagination links for SEO
    current_page = [ params[:page].to_i, 1 ].max
    # We don't know total pages without an extra query, so we set next if we have a full page
    has_more = @content_items.size >= PER_PAGE
    set_pagination_links(
      current_page: current_page,
      total_pages: has_more ? nil : current_page,
      base_params: { tag: params[:tag], content_type: params[:content_type] }.compact
    )
  end
end
