# frozen_string_literal: true

class Admin::NetworkBoostsController < ApplicationController
  include AdminAccess

  before_action :set_boost, only: [ :show, :edit, :update, :destroy ]

  def index
    @boosts = NetworkBoost.where(target_site: Current.site)
                          .includes(source_site: :primary_domain)
                          .order(created_at: :desc)

    @stats = calculate_stats
  end

  def show
    @stats = BoostAttributionService.boost_stats(@boost)
  end

  def new
    @boost = NetworkBoost.new(target_site: Current.site)
    @available_sites = NetworkBoostService.available_targets(Current.site)
  end

  def create
    @boost = NetworkBoost.new(boost_params)
    @boost.target_site = Current.site

    if @boost.save
      redirect_to admin_network_boost_path(@boost), notice: t("admin.network_boosts.created")
    else
      @available_sites = NetworkBoostService.available_targets(Current.site)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_sites = NetworkBoostService.available_targets(Current.site) + [ @boost.source_site ]
  end

  def update
    if @boost.update(boost_params)
      redirect_to admin_network_boost_path(@boost), notice: t("admin.network_boosts.updated")
    else
      @available_sites = NetworkBoostService.available_targets(Current.site) + [ @boost.source_site ]
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @boost.destroy
    redirect_to admin_network_boosts_path, notice: t("admin.network_boosts.destroyed")
  end

  private

  def set_boost
    @boost = NetworkBoost.where(target_site: Current.site).find(params[:id])
  end

  def boost_params
    params.require(:network_boost).permit(:source_site_id, :cpc_rate, :monthly_budget, :enabled)
  end

  def calculate_stats
    boosts = NetworkBoost.where(target_site: Current.site)

    {
      total: boosts.count,
      enabled: boosts.enabled.count,
      with_budget: boosts.enabled.with_budget.count,
      total_impressions: BoostImpression.joins(:network_boost).where(network_boosts: { target_site_id: Current.site.id }).this_month.count,
      total_clicks: BoostClick.joins(:network_boost).where(network_boosts: { target_site_id: Current.site.id }).this_month.count,
      total_spend: BoostClick.joins(:network_boost).where(network_boosts: { target_site_id: Current.site.id }).where(status: [ :confirmed, :paid ]).this_month.sum(:earned_amount)
    }
  end
end
