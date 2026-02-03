# frozen_string_literal: true

module AdminHelper
  # Render a stat card for admin dashboards
  def admin_stat_card(label:, value:, color: "gray", sub_text: nil, icon: nil)
    color_classes = {
      "gray" => "text-gray-900",
      "blue" => "text-blue-600",
      "green" => "text-green-600",
      "red" => "text-red-600",
      "yellow" => "text-yellow-600",
      "purple" => "text-purple-600"
    }

    content_tag(:div, class: "bg-white overflow-hidden shadow rounded-lg p-5") do
      content_tag(:dt, label, class: "text-sm font-medium text-gray-500 truncate") +
      content_tag(:dd, class: "mt-1") do
        content_tag(:span, value, class: "text-3xl font-semibold #{color_classes[color]}") +
        (sub_text ? content_tag(:p, sub_text, class: "text-xs text-gray-400 mt-1") : "".html_safe)
      end
    end
  end

  # Status badge with appropriate colors
  def admin_status_badge(status, options = {})
    colors = {
      # Success states
      "completed" => "bg-green-100 text-green-800",
      "success" => "bg-green-100 text-green-800",
      "published" => "bg-green-100 text-green-800",
      "active" => "bg-green-100 text-green-800",
      "confirmed" => "bg-green-100 text-green-800",
      "approved" => "bg-green-100 text-green-800",
      "enabled" => "bg-green-100 text-green-800",

      # Warning states
      "pending" => "bg-yellow-100 text-yellow-800",
      "processing" => "bg-yellow-100 text-yellow-800",
      "running" => "bg-yellow-100 text-yellow-800",
      "scheduled" => "bg-yellow-100 text-yellow-800",
      "rate_limited" => "bg-yellow-100 text-yellow-800",

      # Error states
      "failed" => "bg-red-100 text-red-800",
      "error" => "bg-red-100 text-red-800",
      "rejected" => "bg-red-100 text-red-800",
      "banned" => "bg-red-100 text-red-800",

      # Neutral states
      "draft" => "bg-gray-100 text-gray-800",
      "skipped" => "bg-gray-100 text-gray-800",
      "disabled" => "bg-gray-100 text-gray-800",

      # Info states
      "info" => "bg-blue-100 text-blue-800"
    }

    status_str = status.to_s.downcase
    color_class = colors[status_str] || "bg-gray-100 text-gray-800"
    label = options[:label] || status.to_s.titleize

    content_tag(:span, label, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{color_class}")
  end

  # Time ago with title showing full date
  def admin_time_ago(time)
    return content_tag(:span, "Never", class: "text-gray-400") if time.nil?

    content_tag(:span, "#{time_ago_in_words(time)} ago", title: time.strftime("%Y-%m-%d %H:%M:%S UTC"))
  end

  # Truncated text with full text in title
  def admin_truncate(text, length: 50)
    return "" if text.blank?

    if text.length > length
      content_tag(:span, truncate(text, length: length), title: text)
    else
      text
    end
  end

  # Format large numbers with delimiters
  def admin_number(value)
    number_with_delimiter(value || 0)
  end

  # Format bytes as human-readable
  def admin_bytes(bytes)
    return "0 B" if bytes.nil? || bytes.zero?

    units = %w[B KB MB GB TB]
    exp = (Math.log(bytes) / Math.log(1024)).to_i
    exp = units.length - 1 if exp >= units.length

    "#{(bytes.to_f / 1024**exp).round(1)} #{units[exp]}"
  end

  # Empty state for lists
  def admin_empty_state(message, icon: "inbox", action: nil)
    content_tag(:div, class: "text-center py-12") do
      icon_svg = case icon
      when "inbox"
        '<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path></svg>'
      when "users"
        '<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path></svg>'
      else
        '<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path></svg>'
      end

      icon_svg.html_safe +
      content_tag(:h3, message, class: "mt-2 text-sm font-medium text-gray-900") +
      (action ? content_tag(:div, action, class: "mt-4") : "".html_safe)
    end
  end
end
