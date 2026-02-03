# frozen_string_literal: true

# UI component helpers for consistent styling across the app
# Reduces duplicate Tailwind class patterns and ensures consistency
module UiHelper
  # Badge/Pill component for status indicators, tags, categories
  # @param text [String] Badge text content
  # @param color [Symbol] Color scheme (:blue, :green, :red, :yellow, :gray, :purple, :indigo)
  # @param size [Symbol] Size variant (:sm, :md)
  # @return [String] HTML badge element
  #
  # Example:
  #   badge("Active", :green)
  #   badge("Pending", :yellow, size: :md)
  #   badge(@listing.category.name, :blue)
  def badge(text, color = :gray, size: :sm)
    color_classes = badge_color_classes(color)
    size_classes = badge_size_classes(size)
    content_tag :span, text, class: "inline-flex items-center rounded-full font-medium #{color_classes} #{size_classes}"
  end

  # Convenience methods for common badge colors
  def badge_success(text, **options) = badge(text, :green, **options)
  def badge_warning(text, **options) = badge(text, :yellow, **options)
  def badge_danger(text, **options)  = badge(text, :red, **options)
  def badge_info(text, **options)    = badge(text, :blue, **options)
  def badge_purple(text, **options)  = badge(text, :purple, **options)
  def badge_gray(text, **options)    = badge(text, :gray, **options)

  # Status badge that auto-selects color based on status
  # @param status [String, Symbol] Status value
  # @return [String] HTML badge with appropriate color
  def status_indicator(status)
    color = case status.to_s.downcase
    when "active", "enabled", "published", "verified", "paid", "approved", "live"
      :green
    when "inactive", "disabled", "draft", "unpaid", "rejected"
      :gray
    when "pending", "review", "scheduled", "awaiting"
      :yellow
    when "error", "failed", "expired", "banned"
      :red
    when "featured", "premium", "pro"
      :purple
    when "info", "new"
      :blue
    else
      :gray
    end
    badge(status.to_s.humanize, color)
  end

  # Type badge for listing types (tool, job, service)
  def type_badge(type)
    color = case type.to_s
    when "tool"    then :blue
    when "job"     then :green
    when "service" then :purple
    else :gray
    end
    badge(type.to_s.humanize, color)
  end

  # Boolean badge (yes/no, enabled/disabled)
  def boolean_badge(value, true_text: "Yes", false_text: "No")
    value ? badge_success(true_text) : badge_gray(false_text)
  end

  # Button component for consistent button styling
  # @param text [String] Button text
  # @param variant [Symbol] Style variant (:primary, :secondary, :danger, :ghost)
  # @param size [Symbol] Size (:sm, :md, :lg)
  # @param options [Hash] Additional HTML attributes
  def button_classes(variant: :primary, size: :md)
    base = "inline-flex items-center justify-center font-medium rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 transition-colors"

    variant_classes = case variant
    when :primary
      "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500 border border-transparent"
    when :secondary
      "bg-white text-gray-700 hover:bg-gray-50 focus:ring-blue-500 border border-gray-300"
    when :danger
      "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500 border border-transparent"
    when :danger_outline
      "bg-white text-red-700 hover:bg-red-50 focus:ring-red-500 border border-red-300"
    when :warning_outline
      "bg-yellow-50 text-yellow-700 hover:bg-yellow-100 focus:ring-yellow-500 border border-yellow-300"
    when :info_outline
      "bg-blue-50 text-blue-700 hover:bg-blue-100 focus:ring-blue-500 border border-blue-300"
    when :success
      "bg-green-600 text-white hover:bg-green-700 focus:ring-green-500 border border-transparent"
    when :purple
      "bg-purple-600 text-white hover:bg-purple-700 focus:ring-purple-500 border border-transparent"
    when :ghost
      "bg-transparent text-gray-600 hover:text-gray-900 hover:bg-gray-100 focus:ring-gray-500"
    else
      "bg-gray-600 text-white hover:bg-gray-700 focus:ring-gray-500 border border-transparent"
    end

    size_classes = case size
    when :xs then "px-2 py-1 text-xs"
    when :sm then "px-3 py-1.5 text-sm"
    when :md then "px-4 py-2 text-sm"
    when :lg then "px-6 py-3 text-base"
    else "px-4 py-2 text-sm"
    end

    "#{base} #{variant_classes} #{size_classes}"
  end

  # Card wrapper for consistent card styling
  def card_classes(padding: true, shadow: true, hover: false)
    classes = [ "bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700" ]
    classes << "p-6" if padding
    classes << "shadow-sm" if shadow
    classes << "hover:shadow-md transition-shadow" if hover
    classes.join(" ")
  end

  # Empty state component
  def empty_state(title:, description: nil, icon: nil, &block)
    content_tag :div, class: "text-center py-12" do
      concat(content_tag(:div, icon, class: "mx-auto h-12 w-12 text-gray-400")) if icon
      concat(content_tag(:h3, title, class: "mt-2 text-sm font-medium text-gray-900 dark:text-white"))
      concat(content_tag(:p, description, class: "mt-1 text-sm text-gray-500 dark:text-gray-400")) if description
      concat(content_tag(:div, class: "mt-6", &block)) if block_given?
    end
  end

  private

  def badge_color_classes(color)
    case color
    when :blue   then "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200"
    when :green  then "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200"
    when :red    then "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200"
    when :yellow then "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200"
    when :purple then "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200"
    when :indigo then "bg-indigo-100 text-indigo-800 dark:bg-indigo-900 dark:text-indigo-200"
    when :pink   then "bg-pink-100 text-pink-800 dark:bg-pink-900 dark:text-pink-200"
    when :gray   then "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
    else "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
    end
  end

  def badge_size_classes(size)
    case size
    when :xs then "px-2 py-0.5 text-xs"
    when :sm then "px-2.5 py-0.5 text-xs"
    when :md then "px-3 py-1 text-sm"
    else "px-2.5 py-0.5 text-xs"
    end
  end
end
