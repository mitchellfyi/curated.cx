# frozen_string_literal: true

# Dynamic robots.txt controller to include tenant-specific sitemap URL
class RobotsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def show
    respond_to do |format|
      format.text { render plain: robots_content }
    end
  end

  private

  def robots_content
    <<~ROBOTS
      # Robots.txt for #{Current.tenant&.title || 'Curated'}
      # See https://www.robotstxt.org/robotstxt.html

      User-agent: *
      Allow: /

      # Disallow admin and user-specific pages
      Disallow: /admin/
      Disallow: /users/
      Disallow: /search

      # Sitemap location
      Sitemap: #{sitemap_url(format: :xml)}
    ROBOTS
  end
end
