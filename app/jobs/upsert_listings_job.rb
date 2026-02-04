# frozen_string_literal: true

# Job to upsert listings from discovered URLs
# Handles deduplication and race conditions
class UpsertListingsJob < ApplicationJob
  queue_as :ingestion

  retry_on ActiveRecord::RecordNotUnique, wait: :polynomially_longer, attempts: 5
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(tenant_id, category_id, url_raw, source_id: nil)
    tenant = Tenant.find(tenant_id)
    category = Category.find(category_id)
    source = source_id ? Source.find(source_id) : nil

    site = category.site || source&.site || tenant.sites.first
    raise "Category must belong to a site" unless site
    raise "Site tenant mismatch" if site.tenant != tenant

    # Set tenant context
    Current.tenant = tenant
    Current.site = site

    # Canonicalize URL
    canonical_url = UrlCanonicaliser.canonicalize(url_raw)
    return if canonical_url.blank?

    # Check if listing already exists
    listing = Listing.find_by(site: site, url_canonical: canonical_url)
    if listing
      # Update source if provided
      listing.update(source: source) if source
      return listing
    end

    # Create new listing (with retry for race conditions)
    listing = create_listing_with_retry(tenant, site, category, url_raw, canonical_url, source)

    # Enqueue metadata scraping
    ScrapeMetadataJob.perform_later(listing.id) if listing.persisted?

    listing
  rescue UrlCanonicaliser::InvalidUrlError => e
    log_job_warning("Invalid URL: #{e.message}", url_raw: url_raw)
    nil
  rescue StandardError => e
    log_job_error(e, url_raw: url_raw, category_id: category_id)
    raise
  ensure
    Current.tenant = nil
    Current.site = nil
  end

  private

  def create_listing_with_retry(tenant, site, category, url_raw, canonical_url, source, retries: 5)
    retries.times do |attempt|
      begin
        return Listing.create!(
          tenant: tenant,
          site: site,
          category: category,
          source: source,
          url_raw: url_raw,
          url_canonical: canonical_url,
          title: extract_title_from_url(canonical_url)
        )
      rescue ActiveRecord::RecordNotUnique
        # Another job created it, fetch it
        listing = Listing.find_by(site: site, url_canonical: canonical_url)
        return listing if listing

        # If still not found, retry after a brief delay
        sleep(0.1 * (attempt + 1))
      end
    end

    # Final attempt
    listing = Listing.find_by(tenant: tenant, url_canonical: canonical_url)
    return listing if listing

    raise "Failed to create or find listing after #{retries} retries"
  end

  def extract_title_from_url(url)
    # Try to extract a basic title from the URL
    uri = URI.parse(url)
    path = uri.path.to_s.gsub(/[\/\-_]/, " ").strip
    path.present? ? path.humanize : "Untitled"
  rescue URI::InvalidURIError
    "Untitled"
  end
end
