# frozen_string_literal: true

class Admin::ModerationController < ApplicationController
  include AdminAccess

  before_action :set_content_item

  # POST /admin/content_items/:id/hide
  def hide
    authorize @content_item, :hide?
    @content_item.hide!(current_user)

    respond_to do |format|
      format.html { redirect_back fallback_location: admin_root_path, notice: I18n.t("admin.moderation.hidden") }
      format.turbo_stream
      format.json { render json: { hidden: true } }
    end
  end

  # POST /admin/content_items/:id/unhide
  def unhide
    authorize @content_item, :unhide?
    @content_item.unhide!

    respond_to do |format|
      format.html { redirect_back fallback_location: admin_root_path, notice: I18n.t("admin.moderation.unhidden") }
      format.turbo_stream
      format.json { render json: { hidden: false } }
    end
  end

  # POST /admin/content_items/:id/lock_comments
  def lock_comments
    authorize @content_item, :lock_comments?
    @content_item.lock_comments!(current_user)

    respond_to do |format|
      format.html { redirect_back fallback_location: admin_root_path, notice: I18n.t("admin.moderation.comments_locked") }
      format.turbo_stream
      format.json { render json: { comments_locked: true } }
    end
  end

  # POST /admin/content_items/:id/unlock_comments
  def unlock_comments
    authorize @content_item, :unlock_comments?
    @content_item.unlock_comments!

    respond_to do |format|
      format.html { redirect_back fallback_location: admin_root_path, notice: I18n.t("admin.moderation.comments_unlocked") }
      format.turbo_stream
      format.json { render json: { comments_locked: false } }
    end
  end

  private

  def set_content_item
    @content_item = ContentItem.find(params[:id])
  end
end
