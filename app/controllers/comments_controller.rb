# frozen_string_literal: true

class CommentsController < ApplicationController
  include RateLimitable

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_content_item
  before_action :set_comment, only: %i[show update destroy]
  before_action :check_ban_status, only: %i[create update]
  before_action :check_comments_locked, only: :create

  # Rate limit: 10 comments per hour
  COMMENT_RATE_LIMIT = 10
  COMMENT_RATE_PERIOD = 1.hour

  # GET /content_items/:content_item_id/comments
  def index
    @comments = policy_scope(Comment)
                .for_content_item(@content_item)
                .root_comments
                .includes(:user, :replies)
                .oldest_first

    authorize Comment
  end

  # GET /content_items/:content_item_id/comments/:id
  def show
    authorize @comment
  end

  # POST /content_items/:content_item_id/comments
  def create
    @comment = @content_item.comments.build(comment_params)
    @comment.user = current_user
    @comment.site = Current.site

    authorize @comment

    if rate_limited?(current_user, :comment, limit: COMMENT_RATE_LIMIT, period: COMMENT_RATE_PERIOD)
      return render_rate_limited(message: I18n.t("comments.rate_limited"))
    end

    if @comment.save
      track_action(current_user, :comment)
      respond_to do |format|
        format.html { redirect_back fallback_location: feed_index_path, notice: I18n.t("comments.created") }
        format.turbo_stream
        format.json { render json: @comment, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: feed_index_path, alert: @comment.errors.full_messages.to_sentence }
        format.json { render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /content_items/:content_item_id/comments/:id
  def update
    authorize @comment

    if @comment.update(comment_params)
      @comment.mark_as_edited!
      respond_to do |format|
        format.html { redirect_back fallback_location: feed_index_path, notice: I18n.t("comments.updated") }
        format.turbo_stream
        format.json { render json: @comment }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: feed_index_path, alert: @comment.errors.full_messages.to_sentence }
        format.json { render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /content_items/:content_item_id/comments/:id
  def destroy
    authorize @comment
    @comment.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: feed_index_path, notice: I18n.t("comments.deleted") }
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private

  def set_content_item
    @content_item = ContentItem.find(params[:content_item_id])
  end

  def set_comment
    @comment = @content_item.comments.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end

  def check_ban_status
    if current_user.banned_from?(Current.site)
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: I18n.t("comments.banned") }
        format.json { render json: { error: I18n.t("comments.banned") }, status: :forbidden }
        format.turbo_stream { head :forbidden }
      end
    end
  end

  def check_comments_locked
    if @content_item.comments_locked?
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: I18n.t("comments.locked") }
        format.json { render json: { error: I18n.t("comments.locked") }, status: :forbidden }
        format.turbo_stream { head :forbidden }
      end
    end
  end
end
