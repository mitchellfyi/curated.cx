# frozen_string_literal: true

class FlagsController < ApplicationController
  include RateLimitable

  before_action :authenticate_user!
  before_action :set_flaggable
  before_action :check_ban_status

  # Rate limit: 20 flags per hour
  FLAG_RATE_LIMIT = 20
  FLAG_RATE_PERIOD = 1.hour

  # POST /flags
  def create
    @flag = @flaggable.flags.build(flag_params)
    @flag.user = current_user
    @flag.site = Current.site

    authorize @flag

    if rate_limited?(current_user, :flag, limit: FLAG_RATE_LIMIT, period: FLAG_RATE_PERIOD)
      return render_rate_limited(message: I18n.t("flags.rate_limited"))
    end

    if @flag.save
      track_action(current_user, :flag)
      respond_to do |format|
        format.html { redirect_back fallback_location: feed_index_path, notice: I18n.t("flags.created") }
        format.turbo_stream
        format.json { render json: { success: true, message: I18n.t("flags.created") }, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: feed_index_path, alert: @flag.errors.full_messages.to_sentence }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flag-error", html: @flag.errors.full_messages.to_sentence) }
        format.json { render json: { errors: @flag.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_flaggable
    @flaggable = find_flaggable
    raise ActiveRecord::RecordNotFound, "Flaggable not found" unless @flaggable
  end

  def find_flaggable
    if params[:flaggable_type] == "ContentItem"
      ContentItem.find_by(id: params[:flaggable_id])
    elsif params[:flaggable_type] == "Comment"
      Comment.find_by(id: params[:flaggable_id])
    end
  end

  def flag_params
    params.require(:flag).permit(:reason, :details)
  end

  def check_ban_status
    return unless current_user.banned_from?(Current.site)

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: I18n.t("flags.banned") }
      format.json { render json: { error: I18n.t("flags.banned") }, status: :forbidden }
      format.turbo_stream { head :forbidden }
    end
  end
end
