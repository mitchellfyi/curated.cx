# frozen_string_literal: true

class DiscussionPostsController < ApplicationController
  include RateLimitable
  include BanCheckable

  before_action :authenticate_user!
  before_action :set_discussion
  before_action :set_post, only: %i[update destroy]
  before_action :check_ban_status, only: %i[create update]
  before_action :check_discussion_locked, only: :create

  # POST /discussions/:discussion_id/posts
  def create
    @post = @discussion.posts.build(post_params)
    @post.user = current_user
    @post.site = Current.site

    authorize @post

    if rate_limited?(current_user, :discussion_post, **RateLimitable::LIMITS[:discussion_post])
      return render_rate_limited(message: I18n.t("discussion_posts.rate_limited"))
    end

    if @post.save
      track_action(current_user, :discussion_post)
      respond_to do |format|
        format.html { redirect_to @discussion, notice: I18n.t("discussion_posts.created") }
        format.turbo_stream
        format.json { render json: @post, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to @discussion, alert: @post.errors.full_messages.to_sentence }
        format.json { render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /discussions/:discussion_id/posts/:id
  def update
    authorize @post

    if @post.update(post_params)
      @post.mark_as_edited!
      respond_to do |format|
        format.html { redirect_to @discussion, notice: I18n.t("discussion_posts.updated") }
        format.turbo_stream
        format.json { render json: @post }
      end
    else
      respond_to do |format|
        format.html { redirect_to @discussion, alert: @post.errors.full_messages.to_sentence }
        format.json { render json: { errors: @post.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /discussions/:discussion_id/posts/:id
  def destroy
    authorize @post
    @post.destroy

    respond_to do |format|
      format.html { redirect_to @discussion, notice: I18n.t("discussion_posts.deleted") }
      format.turbo_stream
      format.json { head :no_content }
    end
  end

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
end
