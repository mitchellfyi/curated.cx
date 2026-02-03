# frozen_string_literal: true

require "resolv"

class Admin::DomainsController < ApplicationController
  include AdminAccess

  before_action :set_site
  before_action :set_domain, only: [ :show, :edit, :update, :destroy, :check_dns  ]

  def new
    @domain = @site.domains.build
  end

  def create
    @domain = @site.domains.build(domain_params)

    # Set as primary if it's the first domain
    @domain.primary = true if @site.domains.empty?

    if @domain.save
      redirect_to admin_site_path(@site), notice: t("admin.domains.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @domain.update(domain_params)
      redirect_to admin_site_domain_path(@site, @domain), notice: t("admin.domains.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @domain.destroy
    redirect_to admin_site_path(@site), notice: t("admin.domains.deleted")
  end

  def check_dns
    authorize @domain
    @dns_result = @domain.check_dns!
    respond_to do |format|
      format.html { render :show }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("dns-check-result", partial: "admin/domains/dns_check_result") }
    end
  end

  private

  def set_site
    @site = policy_scope(Site).find(params[:site_id])
  end

  def set_domain
    @domain = @site.domains.find(params[:id])
  end

  def domain_params
    params.require(:domain).permit(:hostname, :primary)
  end
end
