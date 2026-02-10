# frozen_string_literal: true

class ContentViewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_entry

  # POST /entries/:entry_id/views
  def create
    authorize ContentView

    @content_view = @entry.content_views.find_or_initialize_by(
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

  def set_entry
    @entry = Entry.find(params[:entry_id])
  end
end
