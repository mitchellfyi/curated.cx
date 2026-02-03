# frozen_string_literal: true

module Admin
  class NotesController < ApplicationController
    include AdminAccess

    before_action :set_note, only: [ :show, :destroy, :hide, :unhide, :feature, :unfeature ]

    # GET /admin/notes
    def index
      @notes = Note.includes(:user, :site).order(created_at: :desc)

      # Search
      if params[:search].present?
        @notes = @notes.where("body ILIKE ?", "%#{params[:search]}%")
      end

      # Filter by user
      if params[:user_id].present?
        @notes = @notes.where(user_id: params[:user_id])
        @user = User.find(params[:user_id])
      end

      # Filter by status
      case params[:status]
      when "published"
        @notes = @notes.published
      when "drafts"
        @notes = @notes.drafts
      when "hidden"
        @notes = @notes.where.not(hidden_at: nil)
      end

      @notes = @notes.page(params[:page]).per(50)
      @stats = build_stats
    end

    # GET /admin/notes/:id
    def show
      @comments = @note.comments.includes(:user).order(created_at: :asc)
      @votes = @note.votes.includes(:user).order(created_at: :desc).limit(20)
    end

    # DELETE /admin/notes/:id
    def destroy
      @note.destroy
      redirect_to admin_notes_path, notice: "Note deleted."
    end

    # POST /admin/notes/:id/hide
    def hide
      @note.hide!(current_user)
      redirect_to admin_note_path(@note), notice: "Note hidden."
    end

    # POST /admin/notes/:id/unhide
    def unhide
      @note.unhide!
      redirect_to admin_note_path(@note), notice: "Note unhidden."
    end

    # POST /admin/notes/:id/feature
    def feature
      @note.update!(featured_at: Time.current)
      redirect_to admin_note_path(@note), notice: "Note featured."
    end

    # POST /admin/notes/:id/unfeature
    def unfeature
      @note.update!(featured_at: nil)
      redirect_to admin_note_path(@note), notice: "Note unfeatured."
    end

    private

    def set_note
      @note = Note.find(params[:id])
    end

    def build_stats
      {
        total: Note.count,
        published: Note.published.count,
        drafts: Note.drafts.count,
        hidden: Note.where.not(hidden_at: nil).count,
        this_week: Note.where("created_at > ?", 1.week.ago).count
      }
    end
  end
end
