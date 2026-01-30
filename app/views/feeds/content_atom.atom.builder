xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.feed xmlns: "http://www.w3.org/2005/Atom" do
  xml.title "#{Current.tenant&.title || t('app.name')} - Content Feed"
  xml.subtitle Current.tenant&.description || t("app.tagline")
  xml.id root_url
  xml.link href: root_url
  xml.link href: feeds_content_url(format: :atom), rel: "self", type: "application/atom+xml"
  xml.link href: feeds_content_url(format: :rss), rel: "alternate", type: "application/rss+xml"
  xml.updated @content_items.first&.updated_at&.iso8601 || Time.current.iso8601
  xml.generator "Curated.cx", uri: "https://curated.cx"
  xml.rights "#{Time.current.year} #{Current.tenant&.title}"

  # Feed logo/icon
  if Current.tenant&.logo_url.present?
    xml.icon Current.tenant.logo_url
    xml.logo Current.tenant.logo_url
  end

  # Author (required for valid Atom)
  xml.author do
    xml.name Current.tenant&.title || t("app.name")
    xml.uri root_url
  end

  @content_items.each do |item|
    xml.entry do
      xml.id item.url_canonical
      xml.title item.title || t("feed.content.untitled")
      xml.link href: item.url_canonical, rel: "alternate", type: "text/html"
      xml.published item.published_at&.iso8601 || item.created_at.iso8601
      xml.updated item.updated_at&.iso8601 || item.created_at.iso8601

      # Content/summary
      content_parts = []
      content_parts << (item.ai_summary.presence || item.summary.presence || item.description)
      if item.respond_to?(:why_it_matters) && item.why_it_matters.present?
        content_parts << "<p><strong>Why it matters:</strong> #{ERB::Util.html_escape(item.why_it_matters)}</p>"
      end
      content_html = content_parts.compact.join
      xml.content content_html, type: "html" if content_html.present?

      # Source attribution
      if item.source.present?
        xml.source do
          xml.id item.url_canonical
          xml.title item.source.name
        end
      end

      # Categories
      item.topic_tags.each do |tag|
        xml.category term: tag, label: tag.titleize
      end
    end
  end
end
