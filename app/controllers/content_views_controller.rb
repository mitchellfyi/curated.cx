# frozen_string_literal: true

class ContentViewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_content_item

  # POST /content_items/:content_item_id/views
  def create
    authorize ContentView

    @content_view = @content_item.content_views.find_or_initialize_by(
      user: current_user,
      site: Current.site
    )

    if @content_view.new_record?
      @content_view.viewed_at = Time.current
      @content_view.save!
    else
      @content_view.update!(viewed_at: Time.current)
    end

    respond_to do |format|
      format.json { render json: { success: true }, status: :ok }
      format.html { head :ok }
    end
  end

  private

  def set_content_item
    @content_item = ContentItem.find(params[:content_item_id])
  end
end
