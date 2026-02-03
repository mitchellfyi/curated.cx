# frozen_string_literal: true

class Admin::SourcesController < ApplicationController
  include AdminAccess

  before_action :set_source, only: [ :show, :edit, :update, :destroy, :run_now  ]

  def index
    @sources = policy_scope(Source)
      .includes(:site, :import_runs)
      .order(created_at: :desc)
  end

  def show
    @import_runs = @source.import_runs.recent.limit(10)
    @rate_limiter = SerpApiRateLimiter.new(@source)
  end

  def new
    @source = Source.new
    @source.kind = :serp_api_google_news
    @source.config = default_serp_api_config
    @source.schedule = { interval_seconds: 3600 }
  end

  def create
    @source = Source.new(source_params)
    @source.site = Current.site if Current.site.present?

    if @source.save
      redirect_to admin_source_path(@source), notice: t("admin.sources.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @source.update(source_params)
      redirect_to admin_source_path(@source), notice: t("admin.sources.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @source.destroy
    redirect_to admin_sources_path, notice: t("admin.sources.deleted")
  end

  def run_now
    if @source.enabled?
      SerpApiIngestionJob.perform_later(@source.id)
      redirect_to admin_source_path(@source), notice: t("admin.sources.run_queued")
    else
      redirect_to admin_source_path(@source), alert: t("admin.sources.source_disabled")
    end
  end

  private

  def set_source
    @source = policy_scope(Source).find(params[:id])
  end

  def source_params
    params.require(:source).permit(
      :name,
      :kind,
      :enabled,
      :site_id,
      config: {},
      schedule: {}
    ).tap do |permitted|
      # Handle nested config fields from form
      if params[:source][:config].present?
        permitted[:config] = params[:source][:config].to_unsafe_h
      end
      if params[:source][:schedule].present?
        permitted[:schedule] = params[:source][:schedule].to_unsafe_h
      end
    end
  end

  def default_serp_api_config
    {
      api_key: "",
      query: "",
      location: "United States",
      language: "en",
      max_results: 50,
      rate_limit_per_hour: 10
    }
  end
end
