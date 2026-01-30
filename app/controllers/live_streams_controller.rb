# frozen_string_literal: true

class LiveStreamsController < ApplicationController
  before_action :set_live_stream, only: %i[show join leave]

  # GET /live_streams
  def index
    @live_streams = policy_scope(LiveStream)
                    .includes(:user)
                    .order(Arel.sql("CASE WHEN status = 1 THEN 0 ELSE 1 END, scheduled_at ASC"))
  end

  # GET /live_streams/:id
  def show
    authorize @live_stream
  end

  # POST /live_streams/:id/join
  def join
    authorize @live_stream

    viewer = find_or_create_viewer
    viewer.update!(joined_at: Time.current) if viewer.left_at.present?

    @live_stream.refresh_viewer_count!
    @live_stream.update_peak_viewers!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to live_stream_path(@live_stream) }
    end
  end

  # POST /live_streams/:id/leave
  def leave
    authorize @live_stream

    viewer = find_viewer
    viewer&.leave!
    @live_stream.refresh_viewer_count!

    respond_to do |format|
      format.turbo_stream { head :ok }
      format.html { redirect_to live_streams_path }
    end
  end

  private

  def set_live_stream
    @live_stream = LiveStream.find(params[:id])
  end

  def find_or_create_viewer
    if current_user
      @live_stream.viewers.find_or_create_by!(user: current_user, site: Current.site) do |v|
        v.joined_at = Time.current
      end
    else
      session_id = session.id.to_s
      @live_stream.viewers.find_or_create_by!(session_id: session_id, site: Current.site) do |v|
        v.joined_at = Time.current
      end
    end
  end

  def find_viewer
    if current_user
      @live_stream.viewers.find_by(user: current_user)
    else
      @live_stream.viewers.find_by(session_id: session.id.to_s)
    end
  end
end
