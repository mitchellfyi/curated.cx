# frozen_string_literal: true

# Job to upsert directory entries from discovered URLs.
# Handles deduplication and race conditions.
class UpsertEntriesJob < ApplicationJob
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

    Current.tenant = tenant
    Current.site = site

    canonical_url = UrlCanonicaliser.canonicalize(url_raw)
    return if canonical_url.blank?

    entry = Entry.find_by(site: site, url_canonical: canonical_url)
    if entry
      entry.update(source: source) if source
      return entry
    end

    entry = create_entry_with_retry(tenant, site, category, url_raw, canonical_url, source)
    ScrapeMetadataJob.perform_later(entry.id) if entry.persisted?

    entry
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

  def create_entry_with_retry(tenant, site, category, url_raw, canonical_url, source, retries: 5)
    retries.times do |attempt|
      begin
        return Entry.create!(
          site: site,
          tenant: tenant,
          category: category,
          source: source,
          url_raw: url_raw,
          url_canonical: canonical_url,
          entry_kind: :feed,
          title: extract_title_from_url(canonical_url),
          raw_payload: { "url" => url_raw, "ingested_via" => "upsert_entries_job" },
          tags: [ "source:rss" ]
        )
      rescue ActiveRecord::RecordNotUnique
        entry = Entry.find_by(site: site, url_canonical: canonical_url)
        return entry if entry

        sleep(0.1 * (attempt + 1))
      end
    end

    entry = Entry.find_by(site: site, url_canonical: canonical_url)
    return entry if entry

    raise "Failed to create or find entry after #{retries} retries"
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
