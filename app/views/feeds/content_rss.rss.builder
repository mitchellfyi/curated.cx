xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss version: "2.0",
        "xmlns:atom" => "http://www.w3.org/2005/Atom",
        "xmlns:media" => "http://search.yahoo.com/mrss/" do
  xml.channel do
    xml.title "#{Current.tenant&.title || t('app.name')} - Content Feed"
    xml.description Current.tenant&.description || t("app.tagline")
    xml.link root_url
    xml.language I18n.locale.to_s
    xml.lastBuildDate @content_items.first&.published_at&.rfc822 || Time.current.rfc822
    xml.generator "Curated.cx"
    xml.copyright "#{Time.current.year} #{Current.tenant&.title}"
    xml.webMaster "noreply@#{Current.tenant&.hostname || 'curated.cx'}"

    # Channel logo if available
    if Current.tenant&.logo_url.present?
      xml.image do
        xml.url Current.tenant.logo_url
        xml.title Current.tenant.title
        xml.link root_url
      end
    end

    # Self-referential link for RSS readers
    xml.tag! "atom:link", href: feeds_content_url(format: :rss), rel: "self", type: "application/rss+xml"

    @content_items.each do |item|
      xml.item do
        xml.title item.title || t("feed.content.untitled")
        xml.link item.url_canonical
        xml.guid item.url_canonical, isPermaLink: "true"

        # Description combines AI summary and why_it_matters
        description_parts = []
        description_parts << (item.ai_summary.presence || item.summary.presence || item.description)
        description_parts << "\n\nWhy it matters: #{item.why_it_matters}" if item.respond_to?(:why_it_matters) && item.why_it_matters.present?
        description_text = description_parts.compact.join
        xml.description description_text if description_text.present?

        xml.pubDate item.published_at&.rfc822 || item.created_at.rfc822
        xml.source item.source&.name, url: item.url_canonical if item.source.present?

        # Topic tags as categories
        item.topic_tags.each do |tag|
          xml.category tag.titleize
        end
      end
    end
  end
end
