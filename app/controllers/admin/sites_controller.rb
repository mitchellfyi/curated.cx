# frozen_string_literal: true

class Admin::SitesController < ApplicationController
  include AdminAccess

  before_action :set_site, only: [ :show, :edit, :update, :destroy ]

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
    @site = Site.new(site_params.except(:topics))
    @site.tenant = Current.tenant

    # Handle topics separately
    topics_string = params[:site][:topics]
    if topics_string.present?
      topics_array = topics_string.split(",").map(&:strip).reject(&:blank?)
      @site.config ||= {}
      @site.config["topics"] = topics_array
    end

    if @site.save
      redirect_to admin_site_path(@site), notice: t("admin.sites.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    update_params = site_params.except(:topics)

    # Handle topics separately
    topics_string = params[:site][:topics]
    if topics_string.present?
      topics_array = topics_string.split(",").map(&:strip).reject(&:blank?)
      @site.config ||= {}
      @site.config["topics"] = topics_array
      update_params[:config] = @site.config
    end

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
    params.require(:site).permit(:name, :slug, :description)
  end
end
