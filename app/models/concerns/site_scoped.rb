# frozen_string_literal: true

# SiteScoped concern ensures all records are scoped to the current site.
# This is the primary isolation boundary - each domain is its own micro-network.
# Content, votes, comments, and listings never leak across Sites.
module SiteScoped
  extend ActiveSupport::Concern

  included do
    # Validate site presence
    belongs_to :site
    validates :site, presence: true

    # Add site_id to all queries by default, but only if Current.site is set
    # This ensures that unscoped queries (e.g., in console or background jobs)
    # don't fail if Current.site is not explicitly set.
    default_scope { where(site: Current.site) if Current.site }

    # Class methods
    def self.without_site_scope
      unscoped
    end

    def self.for_site(site)
      unscoped.where(site: site)
    end

    def self.require_site!
      raise "Current.site must be set to perform this operation" unless Current.site
    end
  end

  # Instance methods
  def ensure_site_consistency!
    if Current.site && site != Current.site
      raise "Record belongs to different site than Current.site"
    end
  end
end
