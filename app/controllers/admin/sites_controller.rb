# frozen_string_literal: true

class Admin::SitesController < ApplicationController
  include AdminAccess

  before_action :set_site, only: [ :show, :edit, :update, :destroy  ]

  def index
    @sites = policy_scope(Site).includes(:domains, :tenant).order(created_at: :desc)
  end

  def show
    @domains = @site.domains.order(primary: :desc, created_at: :desc)
  end

  def new
    @site = Site.new
    @site.tenant = Current.tenant
  end

  def create
    @site = Site.new(site_params.except(:topics, :scheduling_timezone))
    @site.tenant = Current.tenant
    apply_config_settings(@site)

    if @site.save
      redirect_to admin_site_path(@site), notice: t("admin.sites.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    update_params = site_params.except(:topics, :scheduling_timezone)
    apply_config_settings(@site)
    update_params[:config] = @site.config if @site.config_changed?

    if @site.update(update_params)
      redirect_to admin_site_path(@site), notice: t("admin.sites.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @site.destroy
    redirect_to admin_sites_path, notice: t("admin.sites.deleted")
  end

  private

  def set_site
    @site = policy_scope(Site).find(params[:id])
  end

  def site_params
    params.require(:site).permit(:name, :slug, :description, :topics, :scheduling_timezone)
  end

  def apply_config_settings(site)
    site.config ||= {}

    # Topics
    topics_string = params[:site][:topics]
    if topics_string.present?
      topics_array = topics_string.split(",").map(&:strip).reject(&:blank?)
      site.config["topics"] = topics_array
    end

    # Scheduling timezone
    scheduling_timezone = params[:site][:scheduling_timezone]
    if scheduling_timezone.present?
      site.config["scheduling"] ||= {}
      site.config["scheduling"]["timezone"] = scheduling_timezone
    end
  end
end
