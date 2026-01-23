# frozen_string_literal: true

class Admin::SiteBansController < ApplicationController
  include AdminAccess

  before_action :set_site_ban, only: %i[show destroy]

  # GET /admin/site_bans
  def index
    @site_bans = SiteBan.for_site(Current.site).includes(:user, :banned_by).order(created_at: :desc)
  end

  # GET /admin/site_bans/:id
  def show
  end

  # GET /admin/site_bans/new
  def new
    @site_ban = SiteBan.new
  end

  # POST /admin/site_bans
  def create
    @site_ban = SiteBan.new(site_ban_params)
    @site_ban.site = Current.site
    @site_ban.banned_by = current_user

    if @site_ban.save
      redirect_to admin_site_bans_path, notice: I18n.t("admin.site_bans.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /admin/site_bans/:id
  def destroy
    @site_ban.destroy
    redirect_to admin_site_bans_path, notice: I18n.t("admin.site_bans.destroyed")
  end

  private

  def set_site_ban
    @site_ban = SiteBan.for_site(Current.site).find(params[:id])
  end

  def site_ban_params
    params.require(:site_ban).permit(:user_id, :reason, :expires_at)
  end
end
