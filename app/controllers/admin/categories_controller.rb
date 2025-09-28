# frozen_string_literal: true

class Admin::CategoriesController < ApplicationController
  before_action :set_category, only: [:show, :edit, :update, :destroy]
  before_action :ensure_admin_access
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    @categories = Category.where(tenant: Current.tenant).includes(:listings).order(:name)
  end

  def show
    @recent_listings = @category.listings.recent.limit(10)
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    @category.tenant = Current.tenant

    if @category.save
      redirect_to admin_category_path(@category), notice: t('admin.categories.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to admin_category_path(@category), notice: t('admin.categories.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to admin_categories_path, notice: t('admin.categories.deleted')
  end

  private

  def set_category
    @category = Category.where(tenant: Current.tenant).find(params[:id])
  end

  def category_params
    params.require(:category).permit(:key, :name, :allow_paths, shown_fields: {})
  end

  def ensure_admin_access
    unless current_user&.admin? || (Current.tenant && current_user&.has_role?(:owner, Current.tenant))
      flash[:alert] = "Access denied. Admin privileges required."
      redirect_to root_path
    end
  end
end
