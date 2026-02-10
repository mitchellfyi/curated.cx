# frozen_string_literal: true

# Public controller for viewing landing pages.
# Landing pages are accessed via /p/:slug URLs.
class LandingPagesController < ApplicationController
  skip_after_action :verify_policy_scoped

  def show
    @landing_page = LandingPage.by_slug(params[:slug]).first!
    authorize @landing_page

    # Load featured listings if any listing sections exist
    load_featured_listings if @landing_page.listing_sections.any?

    set_landing_page_meta_tags
  end

  private

  def load_featured_listings
    # Collect all listing IDs from all listing sections
    listing_ids = @landing_page.listing_sections.flat_map { |s| s["listing_ids"] || [] }.uniq

    return if listing_ids.empty?

    @featured_listings = Entry.directory_items
      .where(id: listing_ids)
      .published
      .not_expired
      .includes(:category)
      .index_by(&:id)
  end

  def set_landing_page_meta_tags
    set_meta_tags(
      title: @landing_page.title,
      description: @landing_page.subheadline.presence || @landing_page.headline,
      og: {
        title: @landing_page.title,
        description: @landing_page.subheadline.presence || @landing_page.headline,
        image: @landing_page.hero_image_url,
        type: "website"
      },
      twitter: {
        card: "summary_large_image",
        title: @landing_page.title,
        description: @landing_page.subheadline.presence || @landing_page.headline,
        image: @landing_page.hero_image_url
      }
    )
  end
end
