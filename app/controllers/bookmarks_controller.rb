# frozen_string_literal: true

class BookmarksController < ApplicationController
  before_action :authenticate_user!
  skip_after_action :verify_policy_scoped, only: [ :index ]

  def index
    authorize Bookmark
    @bookmarks = current_user.bookmarks.recent.includes(:bookmarkable)
  end

  def create
    @bookmarkable = find_bookmarkable
    @bookmark = current_user.bookmarks.build(bookmarkable: @bookmarkable)
    authorize @bookmark

    if @bookmark.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path, notice: t("bookmarks.created") }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(dom_id_for_bookmark_button(@bookmarkable), partial: "bookmarks/button", locals: { bookmarkable: @bookmarkable }) }
        format.html { redirect_back fallback_location: root_path, alert: @bookmark.errors.full_messages.join(", ") }
      end
    end
  end

  def destroy
    @bookmark = current_user.bookmarks.find(params[:id])
    authorize @bookmark

    @bookmarkable = @bookmark.bookmarkable
    @bookmark.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: bookmarks_path, notice: t("bookmarks.destroyed") }
    end
  end

  private

  def find_bookmarkable
    case params[:bookmarkable_type]
    when "Entry"
      Entry.find(params[:bookmarkable_id])
    when "Note"
      Note.find(params[:bookmarkable_id])
    else
      raise ActiveRecord::RecordNotFound, "Invalid bookmarkable type"
    end
  end

  def dom_id_for_bookmark_button(bookmarkable)
    "bookmark_button_#{bookmarkable.class.name.underscore}_#{bookmarkable.id}"
  end
  helper_method :dom_id_for_bookmark_button
end
