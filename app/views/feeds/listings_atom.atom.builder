xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.feed xmlns: "http://www.w3.org/2005/Atom" do
  xml.title "#{Current.tenant&.title || t('app.name')} - Listings"
  xml.subtitle "Latest listings from #{Current.tenant&.title || t('app.name')}"
  xml.id listings_url
  xml.link href: listings_url
  xml.link href: feeds_listings_url(format: :atom), rel: "self", type: "application/atom+xml"
  xml.link href: feeds_listings_url(format: :rss), rel: "alternate", type: "application/rss+xml"
  xml.updated @listings.first&.updated_at&.iso8601 || Time.current.iso8601
  xml.generator "Curated.cx", uri: "https://curated.cx"

  # Feed logo
  if Current.tenant&.logo_url.present?
    xml.icon Current.tenant.logo_url
    xml.logo Current.tenant.logo_url
  end

  xml.author do
    xml.name Current.tenant&.title || t("app.name")
    xml.uri root_url
  end

  @listings.each do |listing|
    xml.entry do
      xml.id listing_url(listing)
      xml.title listing.title
      xml.link href: listing_url(listing), rel: "alternate", type: "text/html"
      xml.published listing.published_at&.iso8601 || listing.created_at.iso8601
      xml.updated listing.updated_at&.iso8601 || listing.created_at.iso8601

      # Content
      content_parts = []
      content_parts << "<p>#{ERB::Util.html_escape(listing.description)}</p>" if listing.description.present?
      if listing.category&.category_type == "job"
        job_details = []
        job_details << "<strong>Company:</strong> #{ERB::Util.html_escape(listing.company)}" if listing.company.present?
        job_details << "<strong>Location:</strong> #{ERB::Util.html_escape(listing.location)}" if listing.location.present?
        job_details << "<strong>Salary:</strong> #{ERB::Util.html_escape(listing.salary_range)}" if listing.salary_range.present?
        content_parts << "<p>#{job_details.join(' | ')}</p>" if job_details.any?
      end
      content_html = content_parts.join
      xml.content content_html, type: "html" if content_html.present?

      # Summary
      xml.summary listing.description if listing.description.present?

      # Categories
      xml.category term: listing.category.name, label: listing.category.name if listing.category.present?
      xml.category term: listing.category&.category_type, label: listing.category&.category_type&.titleize if listing.category&.category_type.present?
      xml.category term: "featured", label: "Featured" if listing.featured?
    end
  end
end
