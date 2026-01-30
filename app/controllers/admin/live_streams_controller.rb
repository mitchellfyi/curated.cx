# frozen_string_literal: true

class Admin::LiveStreamsController < ApplicationController
  include AdminAccess

  before_action :set_live_stream, only: %i[show edit update destroy start end_stream]
  before_action :check_streaming_enabled, only: %i[new create]

  # GET /admin/live_streams
  def index
    @live_streams = LiveStream.for_site(Current.site)
                              .includes(:user, :discussion)
                              .order(scheduled_at: :desc)
  end

  # GET /admin/live_streams/:id
  def show
  end

  # GET /admin/live_streams/new
  def new
    @live_stream = LiveStream.new(
      scheduled_at: 1.hour.from_now,
      visibility: Current.site.discussions_default_visibility
    )
  end

  # POST /admin/live_streams
  def create
    @live_stream = LiveStream.new(live_stream_params)
    @live_stream.site = Current.site
    @live_stream.user = current_user

    ActiveRecord::Base.transaction do
      # Create the Mux stream
      mux_service = MuxLiveStreamService.new(Current.site)
      mux_data = mux_service.create_stream(@live_stream.title)

      @live_stream.mux_stream_id = mux_data[:mux_stream_id]
      @live_stream.mux_playback_id = mux_data[:mux_playback_id]
      @live_stream.stream_key = mux_data[:stream_key]

      # Create associated discussion for live chat
      discussion = Discussion.create!(
        title: "Live Chat: #{@live_stream.title}",
        site: Current.site,
        user: current_user,
        visibility: @live_stream.visibility
      )
      @live_stream.discussion = discussion

      @live_stream.save!
    end

    redirect_to admin_live_stream_path(@live_stream),
                notice: I18n.t("admin.live_streams.created")
  rescue MuxLiveStreamService::MuxNotConfiguredError
    flash.now[:alert] = I18n.t("admin.live_streams.mux_not_configured")
    render :new, status: :unprocessable_entity
  rescue MuxLiveStreamService::MuxApiError => e
    flash.now[:alert] = I18n.t("admin.live_streams.mux_error", error: e.message)
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  # GET /admin/live_streams/:id/edit
  def edit
  end

  # PATCH /admin/live_streams/:id
  def update
    if @live_stream.update(live_stream_params)
      redirect_to admin_live_stream_path(@live_stream),
                  notice: I18n.t("admin.live_streams.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/live_streams/:id
  def destroy
    # Delete from Mux if it has a stream ID
    if @live_stream.mux_stream_id.present?
      begin
        mux_service = MuxLiveStreamService.new(Current.site)
        mux_service.delete_stream(@live_stream.mux_stream_id)
      rescue MuxLiveStreamService::MuxApiError => e
        Rails.logger.error("Failed to delete Mux stream: #{e.message}")
        # Continue with deletion even if Mux cleanup fails
      end
    end

    @live_stream.destroy
    redirect_to admin_live_streams_path, notice: I18n.t("admin.live_streams.destroyed")
  end

  # POST /admin/live_streams/:id/start
  def start
    unless @live_stream.can_start?
      redirect_to admin_live_stream_path(@live_stream),
                  alert: I18n.t("admin.live_streams.cannot_start")
      return
    end

    @live_stream.start!
    redirect_to admin_live_stream_path(@live_stream),
                notice: I18n.t("admin.live_streams.started")
  end

  # POST /admin/live_streams/:id/end_stream
  def end_stream
    unless @live_stream.can_end?
      redirect_to admin_live_stream_path(@live_stream),
                  alert: I18n.t("admin.live_streams.cannot_end")
      return
    end

    @live_stream.end!

    # Mark all active viewers as left
    @live_stream.viewers.active.find_each(&:leave!)

    redirect_to admin_live_stream_path(@live_stream),
                notice: I18n.t("admin.live_streams.ended")
  end

  private

  def set_live_stream
    @live_stream = LiveStream.for_site(Current.site).find(params[:id])
  end

  def check_streaming_enabled
    return if Current.site.streaming_enabled?

    redirect_to admin_live_streams_path, alert: I18n.t("admin.live_streams.disabled")
  end

  def live_stream_params
    params.require(:live_stream).permit(:title, :description, :scheduled_at, :visibility)
  end
end
