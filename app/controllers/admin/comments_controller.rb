# frozen_string_literal: true

module Admin
  class CommentsController < ApplicationController
    include AdminAccess

    before_action :set_comment, only: [ :show, :destroy, :hide, :unhide ]

    # GET /admin/comments
    def index
      @comments = Comment.includes(:user, :commentable).order(created_at: :desc)

      # Search
      if params[:search].present?
        @comments = @comments.where("body ILIKE ?", "%#{params[:search]}%")
      end

      # Filter by user
      if params[:user_id].present?
        @comments = @comments.where(user_id: params[:user_id])
        @user = User.find(params[:user_id])
      end

      # Filter by type
      if params[:commentable_type].present?
        @comments = @comments.where(commentable_type: params[:commentable_type])
      end

      # Filter by hidden
      if params[:hidden] == "true"
        @comments = @comments.where.not(hidden_at: nil)
      elsif params[:hidden] == "false"
        @comments = @comments.where(hidden_at: nil)
      end

      @comments = @comments.page(params[:page]).per(50)
      @stats = build_stats
    end

    # GET /admin/comments/:id
    def show
    end

    # DELETE /admin/comments/:id
    def destroy
      @comment.destroy
      redirect_to admin_comments_path, notice: "Comment deleted."
    end

    # POST /admin/comments/:id/hide
    def hide
      @comment.update!(hidden_at: Time.current, hidden_by: current_user)
      redirect_back fallback_location: admin_comments_path, notice: "Comment hidden."
    end

    # POST /admin/comments/:id/unhide
    def unhide
      @comment.update!(hidden_at: nil, hidden_by: nil)
      redirect_back fallback_location: admin_comments_path, notice: "Comment unhidden."
    end

    private

    def set_comment
      @comment = Comment.find(params[:id])
    end

    def build_stats
      {
        total: Comment.count,
        visible: Comment.where(hidden_at: nil).count,
        hidden: Comment.where.not(hidden_at: nil).count,
        this_week: Comment.where("created_at > ?", 1.week.ago).count,
        on_entries: Comment.where(commentable_type: "Entry").count,
        on_notes: Comment.where(commentable_type: "Note").count
      }
    end
  end
end
