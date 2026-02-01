# frozen_string_literal: true

class NoteVotesController < ApplicationController
  include Votable

  before_action :authenticate_user!
  before_action :check_ban_status

  private

  def set_votable
    @votable = Note.find(params[:id])
  end

  def votable_dom_id
    "note-vote-button-#{@votable.id}"
  end

  def votable_partial
    "note_votes/vote_button"
  end

  def votable_partial_locals
    { note: @votable, voted: @voted }
  end

  def votable_fallback_location
    notes_path
  end
end
