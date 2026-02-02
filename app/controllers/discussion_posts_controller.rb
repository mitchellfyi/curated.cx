# frozen_string_literal: true

class DiscussionPostsController < ApplicationController
  include Commentable

  before_action :authenticate_user!
  before_action :set_discussion
  before_action :set_post, only: %i[update destroy]
  before_action :check_ban_status, only: %i[create update]
  before_action :check_discussion_locked, only: :create

  private

  def set_discussion
    @discussion = Discussion.find(params[:discussion_id])
  end

  def set_post
    @post = @discussion.posts.find(params[:id])
  end

  def post_params
    params.require(:discussion_post).permit(:body, :parent_id)
  end

  def check_discussion_locked
    return unless @discussion.locked?

    respond_to do |format|
      format.html { redirect_to @discussion, alert: I18n.t("discussions.locked") }
      format.json { render json: { error: I18n.t("discussions.locked") }, status: :forbidden }
      format.turbo_stream { head :forbidden }
    end
  end

  # Commentable hooks

  def commentable_build_record
    @post = @discussion.posts.build(post_params)
  end

  def commentable_record
    @post
  end

  def commentable_params
    post_params
  end

  def rate_limit_action
    :discussion_post
  end

  def i18n_namespace
    "discussion_posts"
  end

  def commentable_fallback_location
    @discussion
  end

  def commentable_redirect_back?
    false
  end
end
