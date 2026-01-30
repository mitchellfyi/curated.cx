# frozen_string_literal: true

class Admin::DigitalProductsController < ApplicationController
  include AdminAccess

  before_action :set_digital_product, only: %i[show edit update destroy]

  def index
    @digital_products = digital_products_service.all_products
    @dashboard_stats = digital_products_service.dashboard_stats
  end

  def show
    @purchases = @digital_product.purchases.includes(:download_tokens).recent.limit(20)
  end

  def new
    @digital_product = DigitalProduct.new
  end

  def create
    @digital_product = digital_products_service.create_product(digital_product_params)

    if @digital_product.persisted?
      redirect_to admin_digital_product_path(@digital_product), notice: t("admin.digital_products.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if digital_products_service.update_product(@digital_product, digital_product_params)
      redirect_to admin_digital_product_path(@digital_product), notice: t("admin.digital_products.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    digital_products_service.destroy_product(@digital_product)
    redirect_to admin_digital_products_path, notice: t("admin.digital_products.deleted")
  end

  private

  def set_digital_product
    @digital_product = digital_products_service.find_product(params[:id])
  end

  def digital_products_service
    @digital_products_service ||= Admin::DigitalProductsService.new
  end

  def digital_product_params
    params.require(:digital_product).permit(
      :title,
      :slug,
      :description,
      :price_cents,
      :status,
      :file
    )
  end
end
