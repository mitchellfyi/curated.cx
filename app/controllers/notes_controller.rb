# frozen_string_literal: true

class NotesController < ApplicationController
  include RateLimitable
  include BanCheckable

  before_action :authenticate_user!, except: %i[index show]
  before_action :set_note, only: %i[show edit update destroy repost]
  before_action :check_ban_status, only: %i[create update repost]

  # GET /notes
  def index
    authorize Note
    @notes = policy_scope(Note).for_feed.includes(:user, :site).limit(50)
  end

  # GET /notes/:id
  def show
    authorize @note
    @comments = @note.comments.root_comments.includes(:user, :replies).oldest_first
  end

  # GET /notes/new
  def new
    @note = Note.new
    authorize @note
  end

  # GET /notes/:id/edit
  def edit
    authorize @note
  end

  # POST /notes
  def create
    @note = Note.new(note_params)
    @note.user = current_user
    @note.site = Current.site
    authorize @note

    if rate_limited?(current_user, :note, **RateLimitable::LIMITS[:note])
      return render_rate_limited(message: I18n.t("notes.rate_limited"))
    end

    if @note.save
      track_action(current_user, :note)
      @note.publish! if params[:publish].present?

      respond_to do |format|
        format.html { redirect_to @note, notice: I18n.t("notes.created") }
        format.turbo_stream
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /notes/:id
  def update
    authorize @note

    if @note.update(note_params)
      @note.publish! if params[:publish].present? && !@note.published?

      respond_to do |format|
        format.html { redirect_to @note, notice: I18n.t("notes.updated") }
        format.turbo_stream
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /notes/:id
  def destroy
    authorize @note
    @note.destroy

    respond_to do |format|
      format.html { redirect_to notes_path, notice: I18n.t("notes.deleted") }
      format.turbo_stream
    end
  end

  # POST /notes/:id/repost
  def repost
    authorize @note, :repost?

    if rate_limited?(current_user, :note, **RateLimitable::LIMITS[:note])
      return render_rate_limited(message: I18n.t("notes.rate_limited"))
    end

    # Get the original note (in case this is a repost of a repost)
    original = @note.original_note

    @repost = Note.new(
      body: @note.body,
      link_preview: @note.link_preview,
      repost_of: original,
      user: current_user,
      site: Current.site,
      published_at: Time.current
    )

    if @repost.save
      track_action(current_user, :note)

      respond_to do |format|
        format.html { redirect_to @repost, notice: I18n.t("notes.reposted") }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to @note, alert: @repost.errors.full_messages.join(", ") }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { flash: { alert: @repost.errors.full_messages.join(", ") } }) }
      end
    end
  end

  private

  def set_note
    @note = Note.find(params[:id])
  end

  def note_params
    params.require(:note).permit(:body, :image)
  end
end
