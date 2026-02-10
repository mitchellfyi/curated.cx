# frozen_string_literal: true

class CategoriesController < ApplicationController
  before_action :check_tenant_privacy, only: [ :index, :show ]
  before_action :set_category, only: [ :show ]

  def index
    authorize Category
    @categories = policy_scope(Category).includes(:entries).order(:name)

    set_page_meta_tags(
      title: t("categories.index.title"),
      description: t("categories.index.description", tenant: Current.tenant&.title)
    )
  end

  def show
    authorize @category
    @entries = policy_scope(@category.entries.includes(:category))
                      .published.recent
                      .limit(20)

    set_category_meta_tags(@category)
  end

  private

  def set_category
    @category = policy_scope(Category).includes(:tenant).find(params[:id])
  end
end
