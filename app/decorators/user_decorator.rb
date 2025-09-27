class UserDecorator < ApplicationDecorator
  # User-specific presentation logic

  # Display name with fallback
  def display_name
    email.split("@").first.humanize
  end

  def full_display_name
    display_name
  end

  # Avatar handling
  def avatar_image(size: 40, css_class: nil)
    if avatar_url.present?
      avatar_image_tag(size: size, css_class: css_class)
    else
      avatar_placeholder(size: size, name: display_name)
    end
  end

  def avatar_url
    # Placeholder for future avatar implementation
    # Could integrate with Gravatar, Active Storage, etc.
    nil
  end

  # Role-based presentation
  def role_badges_for_tenant(tenant)
    roles = tenant_roles(tenant)
    return [] if roles.empty?

    roles.map do |role|
      role_badge(role.name)
    end
  end

  def highest_role_badge_for_tenant(tenant)
    role = highest_tenant_role(tenant)
    return nil unless role

    role_badge(role.name, primary: true)
  end

  def platform_admin_badge
    return nil unless admin?

    h.content_tag :span, "Admin",
      class: "badge badge-danger",
      title: "Has access to all tenants and system administration"
  end

  # Status and metadata
  def account_status
    if admin?
      h.content_tag :span, "Admin", class: "text-red-600 font-semibold"
    else
      h.content_tag :span, "User", class: "text-gray-600"
    end
  end

  def last_seen
    return "Never" unless respond_to?(:last_sign_in_at) && last_sign_in_at.present?

    display_date(:last_sign_in_at)
  end

  def member_since
    display_date(:created_at)
  end

  # Accessibility helpers
  def user_aria_label
    "User #{display_name}"
  end

  def role_aria_label(role_name)
    "User has #{role_name} role"
  end

  private

  def avatar_image_tag(size:, css_class:)
    h.image_tag avatar_url,
      alt: "#{display_name}'s avatar",
      size: "#{size}x#{size}",
      class: [ "avatar-image", css_class ].compact.join(" "),
      loading: "lazy"
  end

  def role_badge(role_name, primary: false)
    css_classes = [ "badge" ]
    css_classes << (primary ? "badge-primary" : role_badge_class(role_name))

    h.content_tag :span, role_name.humanize,
      class: css_classes.join(" "),
      title: role_description(role_name),
      'aria-label': role_aria_label(role_name)
  end

  def role_badge_class(role_name)
    case role_name.to_s
    when "owner" then "badge-success"
    when "admin" then "badge-warning"
    when "editor" then "badge-info"
    when "viewer" then "badge-secondary"
    else "badge-light"
    end
  end

  def role_description(role_name)
    case role_name.to_s
    when "owner" then "Full access including tenant management"
    when "admin" then "Administrative access to tenant content"
    when "editor" then "Can create and edit content"
    when "viewer" then "Read-only access to content"
    else "Custom role"
    end
  end
end
