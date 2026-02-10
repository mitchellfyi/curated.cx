# frozen_string_literal: true

class VotesController < ApplicationController
  include Votable

  before_action :authenticate_user!
  before_action :check_ban_status

  private

  def set_votable
    @votable = Entry.find(params[:id])
  end

  def votable_dom_id
    "vote-button-#{@votable.id}"
  end

  def votable_partial
    "votes/vote_button"
  end

  def votable_partial_locals
    { entry: @votable, voted: @voted }
  end

  def votable_fallback_location
    feed_index_path
  end
end
