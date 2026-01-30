# frozen_string_literal: true

class DigitalProductsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :check_digital_products_enabled
  before_action :set_digital_product, only: :show

  # GET /products
  def index
    @digital_products = DigitalProduct.visible.recent.includes(:site)
  end

  # GET /products/:id
  def show
    # Product found by slug in set_digital_product
  end

  private

  def set_digital_product
    @digital_product = DigitalProduct.visible.find_by!(slug: params[:id])
  end

  def check_digital_products_enabled
    return if Current.site&.digital_products_enabled?

    respond_to do |format|
      format.html { redirect_to root_path, alert: I18n.t("digital_products.disabled") }
      format.json { render json: { error: I18n.t("digital_products.disabled") }, status: :forbidden }
    end
  end
end
