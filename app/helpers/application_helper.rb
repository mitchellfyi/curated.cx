module ApplicationHelper
  # General purpose helpers - model-specific logic moved to decorators

  # Internationalization helpers
  def current_locale_name
    I18n.t("locales.#{I18n.locale}", default: I18n.locale.to_s.upcase)
  end

  def locale_options
    I18n.available_locales.map do |locale|
      [ I18n.t("locales.#{locale}", default: locale.to_s.upcase), locale ]
    end
  end

  def rtl_locale?
    %i[ar he].include?(I18n.locale)
  end

  def sr_only(text)
    content_tag :span, text, class: "sr-only"
  end

  # Icon with accessibility text
  def icon_with_text(icon_class, text, options = {})
    content_tag :span, **options do
      concat content_tag(:span, "", class: icon_class, 'aria-hidden': true)
      concat sr_only(text)
    end
  end

  # Form helpers with better accessibility
  def accessible_form_with(model: nil, **options, &block)
    options[:role] = "form" unless options.key?(:role)

    # Handle nil model case properly
    if model.nil?
      options[:url] = options[:url] || "#"
      form_with(**options, &block)
    else
      form_with(model: model, **options, &block)
    end
  end

  # Generic badge helper
  def status_badge(status, type: nil)
    css_class = badge_class_for_status(status, type)
    content_tag :span, status.to_s.humanize, class: "badge #{css_class}"
  end

  # Generic display date helper
  def display_time_ago(date)
    return "Never" unless date.present?

    if date > 1.year.ago
      time_ago_in_words(date) + " ago"
    else
      l(date, format: :short)
    end
  end

  # Flash message helper with proper styling
  def flash_messages
    flash.map do |type, message|
      next if message.blank?

      flash_message_classes = case type
      when "notice"
        "bg-green-50 border border-green-200 text-green-800"
      when "alert"
        "bg-red-50 border border-red-200 text-red-800"
      else
        "bg-blue-50 border border-blue-200 text-blue-800"
      end

      content_tag :div, message,
        class: "px-4 py-3 rounded-md mx-4 mt-4 #{flash_message_classes}",
        role: "alert",
        'aria-live': type == "alert" ? "assertive" : "polite"
    end.compact.join.html_safe
  end

  # Current user avatar (uses decorator)
  def current_user_avatar(size: 32, css_class: nil)
    return nil unless user_signed_in?

    current_user.decorate.avatar_image(size: size, css_class: css_class)
  end

  # Current tenant logo (uses decorator)
  def current_tenant_logo(size: nil, css_class: nil)
    return nil unless Current.tenant

    Current.tenant.decorate.logo_image(size: size, css_class: css_class)
  end

  # Page title helper (still needed for meta tags)
  def page_title(title = nil)
    base_title = Current.tenant&.title || t("app.name")
    if title.present?
      "#{title} | #{base_title}"
    else
      base_title
    end
  end

  # Meta tags and SEO helpers
  def setup_meta_tags(options = {})
    defaults = {
      site: Current.tenant&.title || t("app.name"),
      title: page_title(options[:title]),
      description: options[:description] || Current.tenant&.description || t("app.tagline"),
      keywords: options[:keywords] || (Current.tenant&.enabled_categories&.join(", ")),
      canonical: options[:canonical] || request.original_url,
      og: {
        title: options[:og_title] || page_title(options[:title]),
        description: options[:og_description] || Current.tenant&.description || t("app.tagline"),
        type: options[:og_type] || "website",
        url: options[:og_url] || request.original_url,
        site_name: Current.tenant&.title || t("app.name"),
        locale: I18n.locale,
        image: options[:og_image] || Current.tenant&.logo_url
      },
      twitter: {
        card: options[:twitter_card] || "summary_large_image",
        site: options[:twitter_site] || "@#{Current.tenant&.slug}",
        title: options[:twitter_title] || page_title(options[:title]),
        description: options[:twitter_description] || Current.tenant&.description || t("app.tagline"),
        image: options[:twitter_image] || Current.tenant&.logo_url
      }
    }

    # Remove nil values to avoid empty meta tags
    defaults = deep_compact(defaults)

    set_meta_tags(defaults)
  end

  private

  # Helper method to remove nil values from nested hashes
  def deep_compact(hash)
    hash.compact.transform_values do |value|
      value.is_a?(Hash) ? deep_compact(value) : value
    end.reject { |_, value| value.is_a?(Hash) && value.empty? }
  end

  def badge_class_for_status(status, type)
    return "badge-#{type}" if type.present?

    case status.to_s.downcase
    when "active", "enabled", "published", "success"
      "badge-success"
    when "inactive", "disabled", "unpublished", "draft"
      "badge-secondary"
    when "pending", "review", "warning"
      "badge-warning"
    when "error", "failed", "danger"
      "badge-danger"
    when "info", "information"
      "badge-info"
    else
      "badge-light"
    end
  end
end
