# frozen_string_literal: true

class Admin::CategoriesController < ApplicationController
  include AdminAccess

  before_action :set_category, only: [ :show, :edit, :update, :destroy  ]

  def index
    @categories = categories_service.all_categories
  end

  def show
    @recent_listings = @category.listings.includes(:category).recent.limit(10)
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    @category.site = Current.site
    @category.tenant = Current.tenant # Set tenant for backward compatibility

    if @category.save
      redirect_to admin_category_path(@category), notice: t("admin.categories.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to admin_category_path(@category), notice: t("admin.categories.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to admin_categories_path, notice: t("admin.categories.deleted")
  end

  private

  def set_category
    @category = categories_service.find_category(params[:id])
  end

  def categories_service
    @categories_service ||= Admin::CategoriesService.new(Current.tenant)
  end

  def category_params
    params.require(:category).permit(:key, :name, :allow_paths, shown_fields: {})
  end
end
