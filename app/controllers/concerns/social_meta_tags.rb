# frozen_string_literal: true

# Provides helper methods for setting comprehensive social media meta tags
# including OpenGraph (Facebook, LinkedIn) and Twitter Card tags.
#
# Usage:
#   set_social_meta_tags(
#     title: "Page Title",
#     description: "Page description",
#     image: "https://example.com/image.jpg",
#     url: "https://example.com/page",
#     type: "article"  # or "website", "product"
#   )
#
module SocialMetaTags
  extend ActiveSupport::Concern

  included do
    helper_method :default_social_image_url
  end

  private

  # Set comprehensive social meta tags for a page
  def set_social_meta_tags(options = {})
    tenant = Current.tenant&.decorate
    site_name = tenant&.title || "Curated"

    title = options[:title] || site_name
    description = options[:description] || tenant&.social_description
    image = options[:image] || default_social_image_url
    url = options[:url] || request.original_url
    og_type = options[:type] || "website"

    set_meta_tags(
      title: title,
      description: description,
      canonical: options[:canonical] || url,

      # OpenGraph tags (Facebook, LinkedIn, etc.)
      og: {
        site_name: site_name,
        title: title,
        description: description,
        type: og_type,
        url: url,
        image: image,
        locale: "en_US"
      }.compact,

      # Twitter Card tags
      twitter: {
        card: "summary_large_image",
        site: tenant&.twitter_handle,
        title: title,
        description: description,
        image: image
      }.compact
    )
  end

  # Set meta tags for an article/content item
  def set_article_meta_tags(article, options = {})
    tenant = Current.tenant&.decorate

    set_social_meta_tags(
      title: options[:title] || article.title,
      description: options[:description] || article.try(:description) || article.try(:ai_summary),
      image: options[:image] || article.try(:image_url) || default_social_image_url,
      url: options[:url],
      type: "article"
    )

    # Add article-specific OpenGraph tags
    if article.respond_to?(:published_at) && article.published_at.present?
      set_meta_tags(
        og: {
          "article:published_time": article.published_at.iso8601,
          "article:modified_time": article.updated_at.iso8601,
          "article:section": article.try(:category)&.name
        }.compact
      )
    end
  end

  # Set meta tags for a listing/product
  def set_listing_meta_tags(listing, options = {})
    set_social_meta_tags(
      title: options[:title] || listing.title,
      description: options[:description] || listing.description,
      image: options[:image] || listing.image_url || default_social_image_url,
      url: options[:url] || listing_url(listing),
      type: listing.job? ? "article" : "product"
    )
  end

  # Set meta tags for a category/collection
  def set_category_meta_tags(category, options = {})
    tenant = Current.tenant&.decorate

    set_social_meta_tags(
      title: options[:title] || category.name,
      description: options[:description] || I18n.t("categories.show.description",
                                                     category: category.name,
                                                     tenant: tenant&.title),
      url: options[:url] || category_url(category),
      type: "website"
    )
  end

  # Set meta tags for a user profile
  def set_profile_meta_tags(user, options = {})
    set_social_meta_tags(
      title: options[:title] || I18n.t("profiles.title", name: user.profile_name),
      description: options[:description] || user.bio.presence || I18n.t("profiles.default_description", name: user.profile_name),
      image: options[:image] || user.try(:avatar_url) || default_social_image_url,
      url: options[:url] || profile_url(user),
      type: "profile"
    )
  end

  # Default fallback image for social sharing
  def default_social_image_url
    tenant = Current.tenant&.decorate
    tenant&.social_image_url || helpers.asset_url("default-social.png")
  rescue ActionController::RoutingError
    # Fallback if asset doesn't exist
    nil
  end
end
