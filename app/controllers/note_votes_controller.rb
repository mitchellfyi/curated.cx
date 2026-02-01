# frozen_string_literal: true

class NoteVotesController < ApplicationController
  include RateLimitable
  include BanCheckable

  before_action :authenticate_user!
  before_action :set_note
  before_action :check_ban_status

  # POST /notes/:id/vote
  def toggle
    authorize Vote

    if rate_limited?(current_user, :vote, **RateLimitable::LIMITS[:vote])
      return render_rate_limited(message: I18n.t("votes.rate_limited"))
    end

    @vote = @note.votes.find_by(user: current_user, site: Current.site)

    if @vote
      @vote.destroy
      @voted = false
    else
      @vote = @note.votes.create!(user: current_user, site: Current.site, value: 1)
      track_action(current_user, :vote)
      @voted = true
    end

    respond_to do |format|
      format.html { redirect_back fallback_location: notes_path }
      format.turbo_stream { render_vote_update }
      format.json { render json: { voted: @voted, count: @note.reload.upvotes_count } }
    end
  end

  private

  def set_note
    @note = Note.find(params[:id])
  end

  def render_vote_update
    render turbo_stream: turbo_stream.replace(
      "note-vote-button-#{@note.id}",
      partial: "note_votes/vote_button",
      locals: { note: @note, voted: @voted }
    )
  end
end
