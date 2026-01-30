class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Include Pundit for authorization
  include Pundit::Authorization

  # Include Draper for decorators
  before_action :setup_draper_context

  # Include meta-tags helper for SEO
  include MetaTags::ControllerHelper
  include SocialMetaTags

  # Set default meta tags for all requests
  before_action :set_default_meta_tags

  # Pundit authorization callbacks
  after_action :verify_authorized, unless: -> { devise_controller? }
  after_action :verify_policy_scoped, if: -> { !devise_controller? && action_name == "index" }

  # Handle Pundit authorization errors
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def setup_draper_context
    # Make current_user available in decorators
    if respond_to?(:current_user)
      Draper::ViewContext.current.define_singleton_method(:current_user) { current_user }
    end
  end

  def user_not_authorized
    respond_to do |format|
      format.json { render json: { error: "Forbidden" }, status: :forbidden }
      format.turbo_stream { head :forbidden }
      format.rss { redirect_to new_user_session_path }
      format.html do
        # If user is not signed in, redirect to sign in page
        if !user_signed_in?
          flash[:alert] = t("auth.unauthorized")
          redirect_to new_user_session_path
        elsif params[:controller].to_s.start_with?("admin/")
          # For admin controllers, redirect with admin-specific message
          flash[:alert] = "Access denied. Admin privileges required."
          redirect_to root_path
        else
          # If user is signed in but not authorized, redirect to previous page or root
          flash[:alert] = t("auth.unauthorized")
          redirect_to(request.referrer || root_path)
        end
      end
    end
  end

  def set_default_meta_tags
    return unless Current.tenant

    # Use decorator for better presentation logic
    tenant = Current.tenant.decorate

    set_meta_tags(
      title: tenant.social_title,
      description: tenant.social_description,
      keywords: tenant.enabled_categories_list,
      canonical: tenant.absolute_url(request.path),
      og: {
        title: tenant.social_title,
        description: tenant.social_description,
        type: "website",
        url: tenant.absolute_url(request.path),
        site_name: tenant.title,
        locale: "en_US",
        image: tenant.social_image_url
      },
      twitter: {
        card: "summary_large_image",
        site: tenant.twitter_handle,
        title: tenant.social_title,
        description: tenant.social_description,
        image: tenant.social_image_url
      }
    )
  end

  # Helper method for controllers to easily set page-specific meta tags
  def set_page_meta_tags(options = {})
    # This can be overridden in individual controllers
    set_meta_tags(options)
  end

  # Check if tenant requires authentication for public routes
  def check_tenant_privacy
    return unless Current.tenant&.requires_login?

    unless user_signed_in?
      flash[:alert] = t("auth.requires_authentication")
      redirect_to new_user_session_path
    end
  end
end
