class ApplicationDecorator < Draper::Decorator
  # Global decoration methods available to all decorators

  # Delegate common methods to the decorated object
  delegate_all

  # Common display helpers
  def display_date(date_attribute)
    date = object.send(date_attribute)
    return nil unless date.present?

    if date > 1.year.ago
      h.time_ago_in_words(date) + " ago"
    else
      h.l(date, format: :short)
    end
  end

  def display_status(status_attribute)
    status = object.send(status_attribute)
    return nil unless status.present?

    h.content_tag(:span, status.humanize, class: "badge badge-#{status}")
  end

  # Avatar/image placeholder helper
  def avatar_placeholder(size: 40, name: nil)
    name ||= display_name || "User"
    initials = name.split(" ").map(&:first).join("").upcase[0, 2]

    h.content_tag :div, initials,
      class: "avatar-placeholder",
      style: "width: #{size}px; height: #{size}px; line-height: #{size}px;",
      'aria-label': "#{name}'s avatar"
  end

  protected

  def display_name
    # Override in subclasses to provide appropriate name logic
    nil
  end
end
