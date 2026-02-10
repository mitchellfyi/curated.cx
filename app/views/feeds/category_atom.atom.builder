xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.feed xmlns: "http://www.w3.org/2005/Atom" do
  xml.title "#{@category.name} - #{Current.tenant&.title || t('app.name')}"
  xml.subtitle "#{@category.name} listings from #{Current.tenant&.title}"
  xml.id category_url(@category)
  xml.link href: category_url(@category)
  xml.link href: feeds_category_url(@category, format: :atom), rel: "self", type: "application/atom+xml"
  xml.link href: feeds_category_url(@category, format: :rss), rel: "alternate", type: "application/rss+xml"
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

      xml.summary listing.description if listing.description.present?

      # Categories
      xml.category term: @category.name, label: @category.name
      xml.category term: listing.category&.category_type, label: listing.category&.category_type&.titleize if listing.category&.category_type.present?
      xml.category term: "featured", label: "Featured" if listing.featured?
    end
  end
end
