# frozen_string_literal: true

class Admin::TaxonomiesController < ApplicationController
  include AdminAccess

  before_action :set_taxonomy, only: [ :show, :edit, :update, :destroy ]

  def index
    @taxonomies = taxonomies_service.root_taxonomies
  end

  def show
    @children = @taxonomy.children.by_position
    @tagging_rules = @taxonomy.tagging_rules.by_priority
  end

  def new
    @taxonomy = Taxonomy.new
    @parent_options = taxonomies_service.all_taxonomies
  end

  def create
    @taxonomy = Taxonomy.new(taxonomy_params)
    @taxonomy.site = Current.site
    @taxonomy.tenant = Current.tenant

    if @taxonomy.save
      redirect_to admin_taxonomy_path(@taxonomy), notice: t("admin.taxonomies.created")
    else
      @parent_options = taxonomies_service.all_taxonomies
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @parent_options = taxonomies_service.all_taxonomies.reject { |t| t.id == @taxonomy.id }
  end

  def update
    if @taxonomy.update(taxonomy_params)
      redirect_to admin_taxonomy_path(@taxonomy), notice: t("admin.taxonomies.updated")
    else
      @parent_options = taxonomies_service.all_taxonomies.reject { |t| t.id == @taxonomy.id }
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @taxonomy.destroy
    redirect_to admin_taxonomies_path, notice: t("admin.taxonomies.deleted")
  end

  private

  def set_taxonomy
    @taxonomy = taxonomies_service.find_taxonomy(params[:id])
  end

  def taxonomies_service
    @taxonomies_service ||= Admin::TaxonomiesService.new(Current.tenant)
  end

  def taxonomy_params
    params.require(:taxonomy).permit(:name, :slug, :description, :parent_id, :position)
  end
end
