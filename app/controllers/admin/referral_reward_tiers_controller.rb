# frozen_string_literal: true

class Admin::ReferralRewardTiersController < ApplicationController
  include AdminAccess

  before_action :set_tier, only: [ :show, :edit, :update, :destroy ]

  def index
    @tiers = ReferralRewardTier.where(site: Current.site)
                               .ordered_by_milestone
  end

  def show
  end

  def new
    @tier = ReferralRewardTier.new(site: Current.site)
  end

  def create
    @tier = ReferralRewardTier.new(tier_params)
    @tier.site = Current.site

    if @tier.save
      redirect_to admin_referral_reward_tiers_path, notice: t("admin.referral_reward_tiers.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tier.update(tier_params)
      redirect_to admin_referral_reward_tiers_path, notice: t("admin.referral_reward_tiers.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tier.destroy
    redirect_to admin_referral_reward_tiers_path, notice: t("admin.referral_reward_tiers.deleted")
  end

  private

  def set_tier
    @tier = ReferralRewardTier.find(params[:id])
  end

  def tier_params
    params.require(:referral_reward_tier).permit(:milestone, :reward_type, :name, :description, :active, :digital_product_id).tap do |p|
      # Handle reward_data as JSON
      if params[:referral_reward_tier][:reward_data].present?
        begin
          p[:reward_data] = JSON.parse(params[:referral_reward_tier][:reward_data])
        rescue JSON::ParserError
          # Keep as-is, validation will catch invalid JSON
          p[:reward_data] = params[:referral_reward_tier][:reward_data]
        end
      end
    end
  end
end
