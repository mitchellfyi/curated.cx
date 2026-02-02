# frozen_string_literal: true

class NoteCommentsController < ApplicationController
  include Commentable

  before_action :authenticate_user!, except: :index
  before_action :set_note
  before_action :set_comment, only: %i[update destroy]
  before_action :check_ban_status, only: %i[create update]

  # GET /notes/:note_id/comments
  def index
    @comments = policy_scope(Comment)
                .for_note(@note)
                .root_comments
                .includes(:user, :replies)
                .oldest_first

    authorize Comment
  end

  private

  def set_note
    @note = Note.find(params[:note_id])
  end

  def set_comment
    @comment = @note.comments.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end

  # Commentable hooks

  def commentable_build_record
    @comment = @note.comments.build(comment_params)
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
    @note
  end
end
