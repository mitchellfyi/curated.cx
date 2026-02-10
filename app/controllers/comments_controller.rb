# frozen_string_literal: true

class CommentsController < ApplicationController
  include Commentable

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_entry
  before_action :set_comment, only: %i[show update destroy]
  before_action :check_ban_status, only: %i[create update]
  before_action :check_comments_locked, only: :create

  # GET /entries/:entry_id/comments
  def index
    @comments = policy_scope(Comment)
                .for_entry(@entry)
                .root_comments
                .includes(:user, :replies)
                .oldest_first

    authorize Comment
  end

  # GET /content_items/:content_item_id/comments/:id
  def show
    authorize @comment
  end

  private

  def set_entry
    @entry = Entry.find(params[:entry_id])
  end

  def set_comment
    @comment = @entry.comments.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end

  def check_comments_locked
    if @entry.comments_locked?
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: I18n.t("comments.locked") }
        format.json { render json: { error: I18n.t("comments.locked") }, status: :forbidden }
        format.turbo_stream { head :forbidden }
      end
    end
  end

  # Commentable hooks

  def commentable_build_record
    @comment = @entry.comments.build(comment_params)
  end

  def commentable_record
    @comment
  end

  def commentable_params
    comment_params
  end

  def rate_limit_action
    :comment
  end

  def i18n_namespace
    "comments"
  end

  def commentable_fallback_location
    feed_index_path
  end
end
