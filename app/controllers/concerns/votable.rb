# frozen_string_literal: true

# Votable concern provides shared voting toggle logic for controllers.
# Include this module in controllers that handle votes on polymorphic votable models.
#
# Example usage:
#   class VotesController < ApplicationController
#     include Votable
#
#     private
#
#     def set_votable
#       @votable = ContentItem.find(params[:id])
#     end
#
#     def votable_dom_id
#       "vote-button-#{@votable.id}"
#     end
#
#     def votable_partial
#       "votes/vote_button"
#     end
#
#     def votable_partial_locals
#       { content_item: @votable, voted: @voted }
#     end
#
#     def votable_fallback_location
#       feed_index_path
#     end
#   end
module Votable
  extend ActiveSupport::Concern

  include RateLimitable
  include BanCheckable

  included do
    before_action :set_votable
  end

  # POST /resource/:id/vote
  def toggle
    authorize Vote

    if rate_limited?(current_user, :vote, **RateLimitable::LIMITS[:vote])
      return render_rate_limited(message: I18n.t("votes.rate_limited"))
    end

    @vote = @votable.votes.find_by(user: current_user, site: Current.site)

    if @vote
      @vote.destroy
      @voted = false
    else
      @vote = @votable.votes.create!(user: current_user, site: Current.site, value: 1)
      track_action(current_user, :vote)
      @voted = true
    end

    respond_to do |format|
      format.html { redirect_back fallback_location: votable_fallback_location }
      format.turbo_stream { render_vote_update }
      format.json { render json: { voted: @voted, count: @votable.reload.upvotes_count } }
    end
  end

  private

  def render_vote_update
    render turbo_stream: turbo_stream.replace(
      votable_dom_id,
      partial: votable_partial,
      locals: votable_partial_locals
    )
  end

  # Override in controller: sets @votable to the target model instance
  def set_votable
    raise NotImplementedError, "#{self.class}#set_votable must be implemented"
  end

  # Override in controller: returns the DOM ID for turbo_stream replacement
  def votable_dom_id
    raise NotImplementedError, "#{self.class}#votable_dom_id must be implemented"
  end

  # Override in controller: returns the partial path for rendering
  def votable_partial
    raise NotImplementedError, "#{self.class}#votable_partial must be implemented"
  end

  # Override in controller: returns hash of locals for the partial
  def votable_partial_locals
    raise NotImplementedError, "#{self.class}#votable_partial_locals must be implemented"
  end

  # Override in controller: returns fallback location for HTML redirects
  def votable_fallback_location
    raise NotImplementedError, "#{self.class}#votable_fallback_location must be implemented"
  end
end
