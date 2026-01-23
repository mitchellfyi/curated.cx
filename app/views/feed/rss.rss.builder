xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom" do
  xml.channel do
    xml.title Current.tenant&.title || t("app.name")
    xml.description Current.tenant&.description || t("app.tagline")
    xml.link root_url
    xml.language "en"
    xml.lastBuildDate @content_items.first&.published_at&.rfc822 || Time.current.rfc822
    xml.generator "Curated.cx"

    # Self-referential link for RSS readers
    xml.tag! "atom:link", href: feed_rss_url(format: :rss), rel: "self", type: "application/rss+xml"

    @content_items.each do |item|
      xml.item do
        xml.title item.title || t("feed.content.untitled")
        xml.link item.url_canonical
        xml.guid item.url_canonical, isPermaLink: "true"

        # Description combines AI summary and why_it_matters
        description = []
        if item.ai_summary.present?
          description << item.ai_summary
        elsif item.summary.present?
          description << item.summary
        elsif item.description.present?
          description << item.description
        end

        if item.respond_to?(:why_it_matters) && item.why_it_matters.present?
          description << "\n\nWhy it matters: #{item.why_it_matters}"
        end

        xml.description description.join if description.any?

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
