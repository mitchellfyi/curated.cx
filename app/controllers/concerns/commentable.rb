# frozen_string_literal: true

# Commentable concern provides shared create/update/destroy logic for controllers
# that manage user-generated content (comments, discussion posts, etc.).
#
# Include this module in controllers and implement the required hooks.
#
# Example usage:
#   class CommentsController < ApplicationController
#     include Commentable
#
#     private
#
#     def commentable_build_record
#       @comment = @content_item.comments.build(comment_params)
#     end
#
#     def commentable_record
#       @comment
#     end
#
#     def commentable_params
#       comment_params
#     end
#
#     def rate_limit_action
#       :comment
#     end
#
#     def i18n_namespace
#       "comments"
#     end
#
#     def commentable_fallback_location
#       feed_index_path
#     end
#   end
module Commentable
  extend ActiveSupport::Concern

  include RateLimitable
  include BanCheckable

  # POST /resource
  def create
    commentable_build_record
    record = commentable_record
    record.user = current_user
    record.site = Current.site

    authorize record

    if rate_limited?(current_user, rate_limit_action, **RateLimitable::LIMITS[rate_limit_action])
      return render_rate_limited(message: I18n.t("#{i18n_namespace}.rate_limited"))
    end

    if record.save
      track_action(current_user, rate_limit_action)
      respond_to do |format|
        format.html { commentable_redirect(notice: I18n.t("#{i18n_namespace}.created")) }
        format.turbo_stream
        format.json { render json: record, status: :created }
      end
    else
      respond_to do |format|
        format.html { commentable_redirect(alert: record.errors.full_messages.to_sentence) }
        format.json { render json: { errors: record.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /resource/:id
  def update
    record = commentable_record
    authorize record

    if record.update(commentable_params)
      record.mark_as_edited!
      respond_to do |format|
        format.html { commentable_redirect(notice: I18n.t("#{i18n_namespace}.updated")) }
        format.turbo_stream
        format.json { render json: record }
      end
    else
      respond_to do |format|
        format.html { commentable_redirect(alert: record.errors.full_messages.to_sentence) }
        format.json { render json: { errors: record.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /resource/:id
  def destroy
    record = commentable_record
    authorize record
    record.destroy

    respond_to do |format|
      format.html { commentable_redirect(notice: I18n.t("#{i18n_namespace}.deleted")) }
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private

  # Handles redirect with fallback_location for HTML format.
  # Override commentable_redirect_back? to control whether to use redirect_back or redirect_to.
  def commentable_redirect(notice: nil, alert: nil)
    if commentable_redirect_back?
      redirect_back fallback_location: commentable_fallback_location, notice: notice, alert: alert
    else
      redirect_to commentable_fallback_location, notice: notice, alert: alert
    end
  end

  # Override in controller: returns true to use redirect_back, false for redirect_to.
  # Default is true (use redirect_back with fallback_location).
  def commentable_redirect_back?
    true
  end

  # Override in controller: builds and assigns the record instance variable
  def commentable_build_record
    raise NotImplementedError, "#{self.class}#commentable_build_record must be implemented"
  end

  # Override in controller: returns the record instance variable
  def commentable_record
    raise NotImplementedError, "#{self.class}#commentable_record must be implemented"
  end

  # Override in controller: returns permitted params for the record
  def commentable_params
    raise NotImplementedError, "#{self.class}#commentable_params must be implemented"
  end

  # Override in controller: returns the rate limit action symbol (e.g., :comment, :discussion_post)
  def rate_limit_action
    raise NotImplementedError, "#{self.class}#rate_limit_action must be implemented"
  end

  # Override in controller: returns the I18n namespace string (e.g., "comments", "discussion_posts")
  def i18n_namespace
    raise NotImplementedError, "#{self.class}#i18n_namespace must be implemented"
  end

  # Override in controller: returns the fallback location for redirects
  def commentable_fallback_location
    raise NotImplementedError, "#{self.class}#commentable_fallback_location must be implemented"
  end
end
