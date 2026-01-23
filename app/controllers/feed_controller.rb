# frozen_string_literal: true

class FeedController < ApplicationController
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

    set_page_meta_tags(
      title: t("feed.index.title", site: tenant&.title),
      description: t("feed.index.description", site: tenant&.title),
      canonical: feed_index_url,
      alternate: { "application/rss+xml" => feed_rss_url }
    )
  end
end
