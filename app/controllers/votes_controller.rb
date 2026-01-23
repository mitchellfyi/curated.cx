# frozen_string_literal: true

class VotesController < ApplicationController
  include RateLimitable

  before_action :authenticate_user!
  before_action :set_content_item
  before_action :check_ban_status

  # Rate limit: 100 votes per hour
  VOTE_RATE_LIMIT = 100
  VOTE_RATE_PERIOD = 1.hour

  # POST /content_items/:id/vote
  def toggle
    authorize Vote

    if rate_limited?(current_user, :vote, limit: VOTE_RATE_LIMIT, period: VOTE_RATE_PERIOD)
      return render_rate_limited(message: I18n.t("votes.rate_limited"))
    end

    @vote = @content_item.votes.find_by(user: current_user, site: Current.site)

    if @vote
      @vote.destroy
      @voted = false
    else
      @vote = @content_item.votes.create!(user: current_user, site: Current.site, value: 1)
      track_action(current_user, :vote)
      @voted = true
    end

    respond_to do |format|
      format.html { redirect_back fallback_location: feed_index_path }
      format.turbo_stream { render_vote_update }
      format.json { render json: { voted: @voted, count: @content_item.reload.upvotes_count } }
    end
  end

  private

  def set_content_item
    @content_item = ContentItem.find(params[:id])
  end

  def check_ban_status
    if current_user.banned_from?(Current.site)
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: I18n.t("votes.banned") }
        format.json { render json: { error: I18n.t("votes.banned") }, status: :forbidden }
        format.turbo_stream { head :forbidden }
      end
    end
  end

  def render_vote_update
    render turbo_stream: turbo_stream.replace(
      "vote-button-#{@content_item.id}",
      partial: "votes/vote_button",
      locals: { content_item: @content_item, voted: @voted }
    )
  end
end
