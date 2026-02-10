# frozen_string_literal: true

# Generates XML sitemaps following Google's sitemap protocol
# https://www.sitemaps.org/protocol.html
#
# Routes:
#   GET /sitemap.xml       - Sitemap index (links to sub-sitemaps)
#   GET /sitemap/main.xml  - Main pages (home, categories)
#   GET /sitemap/listings.xml - All published listings
#   GET /sitemap/content.xml  - All published content items
#
class SitemapsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # Maximum URLs per sitemap file (Google limit is 50,000)
  MAX_URLS_PER_SITEMAP = 10_000

  def index
    respond_to do |format|
      format.xml { render_sitemap_index }
    end
  end

  def main
    respond_to do |format|
      format.xml { render_main_sitemap }
    end
  end

  def listings
    respond_to do |format|
      format.xml { render_listings_sitemap }
    end
  end

  def content
    respond_to do |format|
      format.xml { render_content_sitemap }
    end
  end

  private

  def render_sitemap_index
    @sitemaps = [
      { loc: sitemap_main_url(format: :xml), lastmod: Time.current },
      { loc: sitemap_listings_url(format: :xml), lastmod: latest_listing_date },
      { loc: sitemap_content_url(format: :xml), lastmod: latest_content_date }
    ]

    render template: "sitemaps/index", formats: [ :xml ]
  end

  def render_main_sitemap
    @urls = []

    # Home page
    @urls << {
      loc: root_url,
      lastmod: Time.current,
      changefreq: "daily",
      priority: 1.0
    }

    # Categories
    categories.find_each do |category|
      @urls << {
        loc: category_url(category),
        lastmod: category.updated_at,
        changefreq: "weekly",
        priority: 0.8
      }
    end

    render template: "sitemaps/urlset", formats: [ :xml ]
  end

  def render_listings_sitemap
    @urls = []

    sitemap_listings.find_each do |listing|
      @urls << {
        loc: listing_url(listing),
        lastmod: listing.updated_at,
        changefreq: "weekly",
        priority: listing.featured? ? 0.9 : 0.7
      }
    end

    render template: "sitemaps/urlset", formats: [ :xml ]
  end

  def render_content_sitemap
    @urls = []

    content_items.find_each do |item|
      @urls << {
        loc: item.url_canonical,
        lastmod: item.updated_at,
        changefreq: "monthly",
        priority: 0.6
      }
    end

    render template: "sitemaps/urlset", formats: [ :xml ]
  end

  def categories
    Category.order(:id)
  end

  def sitemap_listings
    Entry.directory_items
         .published
         .not_expired
         .order(:id)
         .limit(MAX_URLS_PER_SITEMAP)
  end

  def content_items
    Entry.feed_items
         .published
         .not_hidden
         .order(:id)
         .limit(MAX_URLS_PER_SITEMAP)
  end

  def latest_listing_date
    Entry.directory_items.published.maximum(:updated_at) || Time.current
  end

  def latest_content_date
    Entry.feed_items.published.maximum(:updated_at) || Time.current
  end
end
