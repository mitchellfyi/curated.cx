class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Include meta-tags helper for SEO
  include MetaTags::ControllerHelper

  # Set default meta tags for all requests
  before_action :set_default_meta_tags

  private

  def set_default_meta_tags
    return unless Current.tenant

    tenant = Current.tenant
    
    set_meta_tags(
      title: tenant.title,
      description: tenant.description,
      keywords: tenant.enabled_categories.join(", "),
      og: {
        title: tenant.title,
        description: tenant.description,
        type: "website",
        url: request.original_url,
        site_name: tenant.title,
        locale: "en_US"
      },
      twitter: {
        card: "summary_large_image",
        site: "@#{tenant.slug}",
        title: tenant.title,
        description: tenant.description
      }
    )

    # Add logo if available
    if tenant.logo_url.present?
      set_meta_tags(
        og: { image: tenant.logo_url },
        twitter: { image: tenant.logo_url }
      )
    end
  end
end
