xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss version: "2.0",
        "xmlns:atom" => "http://www.w3.org/2005/Atom",
        "xmlns:media" => "http://search.yahoo.com/mrss/" do
  xml.channel do
    xml.title "#{@category.name} - #{Current.tenant&.title || t('app.name')}"
    xml.description "#{@category.name} listings from #{Current.tenant&.title}"
    xml.link category_url(@category)
    xml.language I18n.locale.to_s
    xml.lastBuildDate @listings.first&.published_at&.rfc822 || Time.current.rfc822
    xml.generator "Curated.cx"
    xml.copyright "#{Time.current.year} #{Current.tenant&.title}"

    # Channel logo
    if Current.tenant&.logo_url.present?
      xml.image do
        xml.url Current.tenant.logo_url
        xml.title "#{@category.name} - #{Current.tenant.title}"
        xml.link category_url(@category)
      end
    end

    # Self-referential link
    xml.tag! "atom:link", href: feeds_category_url(@category, format: :rss), rel: "self", type: "application/rss+xml"

    @listings.each do |listing|
      xml.item do
        xml.title listing.title
        xml.link listing_url(listing)
        xml.guid listing_url(listing), isPermaLink: "true"

        # Description
        description = listing.description.presence || listing.body_text&.truncate(500)
        xml.description description if description.present?

        xml.pubDate listing.published_at&.rfc822 || listing.created_at.rfc822

        xml.category @category.name

        # Listing type
        xml.category "Type: #{listing.listing_type.titleize}" if listing.listing_type.present?

        # Featured badge
        xml.category "Featured" if listing.featured?

        # Image
        if listing.image_url.present?
          xml.tag! "media:content", url: listing.image_url, medium: "image"
        end
      end
    end
  end
end
