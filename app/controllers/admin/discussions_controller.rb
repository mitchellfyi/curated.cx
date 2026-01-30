# frozen_string_literal: true

class Admin::DiscussionsController < ApplicationController
  include AdminAccess

  before_action :set_discussion, only: %i[show destroy lock unlock pin unpin]

  # GET /admin/discussions
  def index
    @discussions = Discussion.for_site(Current.site)
                             .pinned_first
                             .includes(:user, :locked_by)
  end

  # GET /admin/discussions/:id
  def show
    @posts = @discussion.posts
                        .root_posts
                        .includes(:user, replies: :user)
                        .oldest_first
  end

  # DELETE /admin/discussions/:id
  def destroy
    @discussion.destroy
    redirect_to admin_discussions_path, notice: I18n.t("admin.discussions.destroyed")
  end

  # POST /admin/discussions/:id/lock
  def lock
    @discussion.lock!(current_user)
    redirect_to admin_discussion_path(@discussion), notice: I18n.t("admin.discussions.locked")
  end

  # POST /admin/discussions/:id/unlock
  def unlock
    @discussion.unlock!
    redirect_to admin_discussion_path(@discussion), notice: I18n.t("admin.discussions.unlocked")
  end

  # POST /admin/discussions/:id/pin
  def pin
    @discussion.pin!
    redirect_to admin_discussion_path(@discussion), notice: I18n.t("admin.discussions.pinned")
  end

  # POST /admin/discussions/:id/unpin
  def unpin
    @discussion.unpin!
    redirect_to admin_discussion_path(@discussion), notice: I18n.t("admin.discussions.unpinned")
  end

  private

  def set_discussion
    @discussion = Discussion.for_site(Current.site).find(params[:id])
  end
end
