# frozen_string_literal: true

class Admin::TaggingRulesController < ApplicationController
  include AdminAccess

  before_action :set_tagging_rule, only: [ :show, :edit, :update, :destroy, :test  ]

  def index
    @tagging_rules = tagging_rules_service.all_rules
  end

  def show
  end

  def new
    @tagging_rule = TaggingRule.new
    @taxonomies = Admin::TaxonomiesService.new(Current.tenant).all_taxonomies
  end

  def create
    @tagging_rule = TaggingRule.new(tagging_rule_params)
    @tagging_rule.site = Current.site
    @tagging_rule.tenant = Current.tenant

    if @tagging_rule.save
      redirect_to admin_tagging_rule_path(@tagging_rule), notice: t("admin.tagging_rules.created")
    else
      @taxonomies = Admin::TaxonomiesService.new(Current.tenant).all_taxonomies
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @taxonomies = Admin::TaxonomiesService.new(Current.tenant).all_taxonomies
  end

  def update
    if @tagging_rule.update(tagging_rule_params)
      redirect_to admin_tagging_rule_path(@tagging_rule), notice: t("admin.tagging_rules.updated")
    else
      @taxonomies = Admin::TaxonomiesService.new(Current.tenant).all_taxonomies
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tagging_rule.destroy
    redirect_to admin_tagging_rules_path, notice: t("admin.tagging_rules.deleted")
  end

  def test
    @content_items = ContentItem.without_site_scope.where(site: Current.site).limit(10)
    @results = @content_items.map do |item|
      {
        content_item: item,
        match_result: @tagging_rule.matches?(item)
      }
    end
  end

  private

  def set_tagging_rule
    @tagging_rule = tagging_rules_service.find_rule(params[:id])
  end

  def tagging_rules_service
    @tagging_rules_service ||= Admin::TaggingRulesService.new(Current.tenant)
  end

  def tagging_rule_params
    params.require(:tagging_rule).permit(:taxonomy_id, :rule_type, :pattern, :priority, :enabled)
  end
end
