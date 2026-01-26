# frozen_string_literal: true

class VotesController < ApplicationController
  include RateLimitable
  include BanCheckable

  before_action :authenticate_user!
  before_action :set_content_item
  before_action :check_ban_status

  # POST /content_items/:id/vote
  def toggle
    authorize Vote

    if rate_limited?(current_user, :vote, **RateLimitable::LIMITS[:vote])
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

  def render_vote_update
    render turbo_stream: turbo_stream.replace(
      "vote-button-#{@content_item.id}",
      partial: "votes/vote_button",
      locals: { content_item: @content_item, voted: @voted }
    )
  end
end
