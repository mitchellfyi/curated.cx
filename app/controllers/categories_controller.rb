# frozen_string_literal: true

class CategoriesController < ApplicationController
  before_action :set_category, only: [:show]

  def index
    authorize Category
    @categories = policy_scope(Category).includes(:listings).order(:name)
    
    set_page_meta_tags(
      title: t('categories.index.title'),
      description: t('categories.index.description', tenant: Current.tenant&.title)
    )
  end

  def show
    authorize @category
    @listings = policy_scope(@category.listings)
                       .recent
                       .limit(20)

    set_page_meta_tags(
      title: @category.name,
      description: t('categories.show.description', 
                    category: @category.name, 
                    tenant: Current.tenant&.title)
    )
  end

  private

  def set_category
    @category = policy_scope(Category).find(params[:id])
  end
end
