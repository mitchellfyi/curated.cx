module ApplicationHelper

  # Accessibility helpers
  def skip_link(target = "#main-content", text = t('a11y.skip_to_content'))
    link_to text, target, class: "skip-link sr-only focus:not-sr-only focus:absolute focus:top-0 focus:left-0 bg-blue-600 text-white p-2 z-50 focus:z-50"
  end


  # Locale management helpers
  def current_locale_name
    I18n.t("locales.#{I18n.locale}", default: I18n.locale.to_s.upcase)
  end

  def locale_options
    I18n.available_locales.map do |locale|
      [I18n.t("locales.#{locale}", default: locale.to_s.upcase), locale]
    end
  end

  def rtl_locale?
    %i[ar he].include?(I18n.locale)
  end

  # ARIA helpers
  def aria_label(key, options = {})
    { 'aria-label': t(key, **options) }
  end

  def aria_describedby(id)
    { 'aria-describedby': id }
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
    options[:role] = 'form' unless options.key?(:role)
    form_with(model: model, **options, &block)
  end

end
