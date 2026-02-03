# frozen_string_literal: true

module Admin
  class ContentItemsController < ApplicationController
    include AdminAccess

    before_action :set_content_item, only: [ :show, :edit, :update, :destroy, :publish, :unpublish, :editorialise ]

    # GET /admin/content_items
    def index
      @content_items = ContentItem.includes(:source, :site).order(created_at: :desc)

      # Search
      if params[:search].present?
        @content_items = @content_items.where("title ILIKE ? OR url_canonical ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
      end

      # Filter by source
      if params[:source_id].present?
        @content_items = @content_items.where(source_id: params[:source_id])
        @source = Source.find(params[:source_id])
      end

      # Filter by status
      case params[:status]
      when "published"
        @content_items = @content_items.published
      when "unpublished"
        @content_items = @content_items.where(published_at: nil)
      when "editorialised"
        @content_items = @content_items.where.not(editorialised_at: nil)
      when "not_editorialised"
        @content_items = @content_items.where(editorialised_at: nil)
      end

      # Filter by tag
      if params[:tag].present?
        @content_items = @content_items.tagged_with(params[:tag])
      end

      @content_items = @content_items.page(params[:page]).per(50)
      @stats = build_stats
      @sources = Source.enabled.order(:name)
    end

    # GET /admin/content_items/:id
    def show
      @editorialisation = @content_item.editorialisation
    end

    # GET /admin/content_items/:id/edit
    def edit
    end

    # PATCH /admin/content_items/:id
    def update
      if @content_item.update(content_item_params)
        redirect_to admin_content_item_path(@content_item), notice: "Content item updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/content_items/:id
    def destroy
      @content_item.destroy
      redirect_to admin_content_items_path, notice: "Content item deleted."
    end

    # POST /admin/content_items/:id/publish
    def publish
      @content_item.update!(published_at: Time.current)
      redirect_to admin_content_item_path(@content_item), notice: "Content item published."
    end

    # POST /admin/content_items/:id/unpublish
    def unpublish
      @content_item.update!(published_at: nil)
      redirect_to admin_content_item_path(@content_item), notice: "Content item unpublished."
    end

    # POST /admin/content_items/:id/editorialise
    def editorialise
      EditorialisationJob.perform_later(@content_item.id)
      redirect_to admin_content_item_path(@content_item), notice: "Editorialisation job queued."
    end

    # POST /admin/content_items/bulk_action
    def bulk_action
      ids = params[:content_item_ids].to_s.split(",").map(&:to_i).reject(&:zero?)

      if ids.empty?
        redirect_to admin_content_items_path, alert: "No items selected."
        return
      end

      items = ContentItem.where(id: ids)
      count = items.count

      case params[:bulk_action]
      when "publish"
        items.update_all(published_at: Time.current)
        redirect_to admin_content_items_path, notice: "#{count} items published."
      when "unpublish"
        items.update_all(published_at: nil)
        redirect_to admin_content_items_path, notice: "#{count} items unpublished."
      when "editorialise"
        items.find_each do |item|
          EditorialisationJob.perform_later(item.id)
        end
        redirect_to admin_content_items_path, notice: "#{count} items queued for editorialisation."
      when "delete"
        items.destroy_all
        redirect_to admin_content_items_path, notice: "#{count} items deleted."
      else
        redirect_to admin_content_items_path, alert: "Unknown action."
      end
    end

    private

    def set_content_item
      @content_item = ContentItem.find(params[:id])
    end

    def content_item_params
      params.require(:content_item).permit(
        :title, :description, :url_raw, :url_canonical,
        :published_at, :scheduled_for,
        :ai_summary, :why_it_matters,
        :content_type, :extracted_text,
        :topic_tags_string,
        topic_tags: [], ai_suggested_tags: []
      )
    end

    def build_stats
      base = @source ? ContentItem.where(source: @source) : ContentItem

      {
        total: base.count,
        published: base.published.count,
        unpublished: base.where(published_at: nil).count,
        editorialised: base.where.not(editorialised_at: nil).count,
        this_week: base.where("created_at > ?", 1.week.ago).count
      }
    end
  end
end
