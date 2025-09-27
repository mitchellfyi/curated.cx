class TenantDecorator < ApplicationDecorator
  # Tenant-specific presentation logic
  
  # Display methods
  def display_name
    title.presence || hostname
  end
  
  def display_description
    description.presence || "Content curated for #{display_name}"
  end
  
  # Logo and branding
  def logo_image(size: nil, css_class: nil)
    if logo_url.present?
      logo_image_tag(size: size, css_class: css_class)
    else
      logo_placeholder(size: size)
    end
  end
  
  def favicon_url
    # Default favicon path or tenant-specific favicon
    logo_url.presence || '/favicon.ico'
  end
  
  # Status and metadata
  def status_badge
    case status
    when 'enabled'
      h.content_tag :span, "Active", class: "badge badge-success"
    when 'disabled'  
      h.content_tag :span, "Disabled", class: "badge badge-danger"
    when 'maintenance'
      h.content_tag :span, "Maintenance", class: "badge badge-warning"
    else
      h.content_tag :span, status.humanize, class: "badge badge-secondary"
    end
  end
  
  def enabled_categories_list
    return "None" if enabled_categories.blank?
    
    enabled_categories.map(&:humanize).to_sentence
  end
  
  def settings_summary
    return {} unless settings.present?
    
    {
      theme: theme_description,
      categories: enabled_categories_count,
      custom_settings: custom_settings_count
    }
  end
  
  # Branding and URLs
  def powered_by_curated?
    !root_tenant?
  end
  
  def root_tenant?
    slug == 'root' || hostname == 'curated.cx'
  end
  
  def curated_main_url
    Rails.env.development? ? 'http://localhost:3000' : 'https://curated.cx'
  end
  
  def powered_by_partial
    return nil unless powered_by_curated?
    'shared/powered_by_footer'
  end
  
  # Environment-aware URL generation
  def absolute_url(path = nil)
    if Rails.env.development?
      # In development, use localhost subdomain pattern for proper tenant resolution
      base_url = "http://#{slug}.localhost:3000"
    else
      base_url = "https://#{hostname}"
    end
    path.present? ? "#{base_url}/#{path.to_s.gsub(/^\//, '')}" : base_url
  end
  
  def admin_dashboard_url
    absolute_url('admin')
  end
  
  # Social media and SEO
  def social_title
    title
  end
  
  def social_description  
    description.presence || "Curated content from #{title}"
  end
  
  def social_image_url
    logo_url.presence || absolute_url('og-image.png')
  end
  
  def twitter_handle
    return nil unless slug.present?
    "@#{slug}"
  end
  
  # Theme and styling
  def primary_color
    settings.dig('theme', 'primary_color') || '#3b82f6'
  end
  
  def secondary_color
    settings.dig('theme', 'secondary_color') || '#6b7280'
  end
  
  def theme_css_variables
    {
      '--primary-color' => primary_color,
      '--secondary-color' => secondary_color
    }.map { |key, value| "#{key}: #{value}" }.join('; ')
  end
  
  # Accessibility
  def tenant_aria_label
    "Tenant: #{display_name}"
  end
  
  def logo_alt_text
    "#{display_name} logo"
  end
  
  # Root tenant specific methods
  def tenant_directory_partial
    return nil unless root_tenant?
    
    enabled_tenants = Tenant.where(status: 'enabled').where.not(slug: 'root')
    return nil if enabled_tenants.empty?
    
    'tenants/directory'
  end
  
  def enabled_tenants_for_directory
    return [] unless root_tenant?
    Tenant.where(status: 'enabled').where.not(slug: 'root')
  end
  
  private
  
  def logo_image_tag(size:, css_class:)
    img_attributes = {
      alt: logo_alt_text,
      class: ['tenant-logo', css_class].compact.join(' '),
      loading: 'lazy'
    }
    
    img_attributes[:size] = "#{size}x#{size}" if size
    
    h.image_tag logo_url, img_attributes
  end
  
  def logo_placeholder(size: nil)
    placeholder_size = size || 40
    initials = display_name.split(' ').map(&:first).join('').upcase[0, 2]
    
    h.content_tag :div, initials,
      class: "tenant-logo-placeholder",
      style: "width: #{placeholder_size}px; height: #{placeholder_size}px; line-height: #{placeholder_size}px; background-color: #{primary_color};",
      'aria-label': logo_alt_text
  end
  
  def theme_description
    return "Default" unless settings.dig('theme').present?
    
    "Custom (#{primary_color})"
  end
  
  def enabled_categories_count
    enabled_categories.size
  end
  
  def custom_settings_count
    return 0 unless settings.present?
    
    settings.except('theme', 'categories').size
  end
end