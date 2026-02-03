# frozen_string_literal: true

# Shared pagination configuration for admin controllers
module AdminPagination
  extend ActiveSupport::Concern

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  included do
    helper_method :per_page if respond_to?(:helper_method)
  end

  private

  def per_page
    requested = params[:per_page].to_i
    return DEFAULT_PER_PAGE if requested <= 0
    [ requested, MAX_PER_PAGE ].min
  end

  def paginate(scope, options = {})
    scope.page(params[:page]).per(options[:per_page] || per_page)
  end
end
