# frozen_string_literal: true

class NoteCommentsController < ApplicationController
  include RateLimitable
  include BanCheckable

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

  # POST /notes/:note_id/comments
  def create
    @comment = @note.comments.build(comment_params)
    @comment.user = current_user
    @comment.site = Current.site

    authorize @comment

    if rate_limited?(current_user, :comment, **RateLimitable::LIMITS[:comment])
      return render_rate_limited(message: I18n.t("comments.rate_limited"))
    end

    if @comment.save
      track_action(current_user, :comment)
      respond_to do |format|
        format.html { redirect_back fallback_location: @note, notice: I18n.t("comments.created") }
        format.turbo_stream
        format.json { render json: @comment, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: @note, alert: @comment.errors.full_messages.to_sentence }
        format.json { render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /notes/:note_id/comments/:id
  def update
    authorize @comment

    if @comment.update(comment_params)
      @comment.mark_as_edited!
      respond_to do |format|
        format.html { redirect_back fallback_location: @note, notice: I18n.t("comments.updated") }
        format.turbo_stream
        format.json { render json: @comment }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: @note, alert: @comment.errors.full_messages.to_sentence }
        format.json { render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /notes/:note_id/comments/:id
  def destroy
    authorize @comment
    @comment.destroy

    respond_to do |format|
      format.html { redirect_back fallback_location: @note, notice: I18n.t("comments.deleted") }
      format.turbo_stream
      format.json { head :no_content }
    end
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
end
