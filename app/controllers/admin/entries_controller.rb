# frozen_string_literal: true

module Admin
  class EntriesController < ApplicationController
    include AdminAccess

    before_action :set_entry, only: %i[
      show edit update destroy publish unpublish editorialise enrich
      feature unfeature extend_expiry unschedule publish_now
      hide unhide lock_comments unlock_comments
    ]
    before_action :set_categories, only: %i[index new create edit update]

    def index
      @entries = base_scope.includes(:source, :site, :category).order(created_at: :desc)

      # Kind filter
      @entries = @entries.feed_items if params[:kind] == "feed"
      @entries = @entries.directory_items if params[:kind] == "directory"

      # Search
      if params[:search].present?
        term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"
        @entries = @entries.where("title ILIKE ? OR url_canonical ILIKE ?", term, term)
      end

      # Filter by source (feed)
      if params[:source_id].present?
        @entries = @entries.where(source_id: params[:source_id])
        @source = Source.find_by(id: params[:source_id])
      end

      # Filter by category (directory)
      @entries = @entries.where(category_id: params[:category_id]) if params[:category_id].present?

      # Status filters
      apply_status_filters

      # Tag filter (feed)
      @entries = @entries.tagged_with(params[:tag]) if params[:tag].present?

      @entries = @entries.page(params[:page]).per(50)
      @stats = build_stats
      @sources = Source.enabled.order(:name)
    end

    def show
      @editorialisation = @entry.editorialisation if @entry.feed?
    end

    def new
      @entry = Entry.new(entry_kind: params[:kind] || "directory")
    end

    def create
      @entry = Entry.new(entry_params.except(:publish_action))
      @entry.site = Current.site
      @entry.tenant = Current.tenant if Current.tenant
      @entry.entry_kind = params[:entry][:entry_kind] || "directory"
      apply_publish_action(@entry, params[:entry][:publish_action], params[:entry][:scheduled_for])

      if @entry.save
        redirect_to admin_entry_path(@entry), notice: t("admin.entries.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attrs = entry_params.except(:publish_action, :published_at, :scheduled_for)
      apply_publish_action(@entry, params[:entry][:publish_action], params[:entry][:scheduled_for])
      attrs[:published_at] = @entry.published_at
      attrs[:scheduled_for] = @entry.scheduled_for
      if @entry.update(attrs)
        redirect_to admin_entry_path(@entry), notice: t("admin.entries.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @entry.destroy
      redirect_to admin_entries_path, notice: t("admin.entries.deleted")
    end

    # Publishing
    def publish
      @entry.update!(published_at: Time.current)
      redirect_to admin_entry_path(@entry), notice: t("admin.entries.published")
    end

    def unpublish
      @entry.update!(published_at: nil)
      redirect_to admin_entry_path(@entry), notice: t("admin.entries.unpublished")
    end

    # Feed-only: editorialise / enrich
    def editorialise
      return head :unprocessable_entity unless @entry.feed?
      EditorialiseEntryJob.perform_later(@entry.id)
      redirect_to admin_entry_path(@entry), notice: t("admin.entries.editorialise_queued")
    end

    def enrich
      return head :unprocessable_entity unless @entry.feed?
      @entry.reset_enrichment!
      EnrichEntryJob.perform_later(@entry.id)
      redirect_to admin_entry_path(@entry), notice: t("admin.entries.enrich_queued")
    end

    # Directory: feature / scheduling
    def feature
      @entry.update!(
        featured_from: Time.current,
        featured_until: params[:featured_until] || 30.days.from_now,
        featured_by: current_user
      )
      redirect_to admin_entry_path(@entry), notice: t("admin.entries.featured")
    end

    def unfeature
      @entry.update!(featured_from: nil, featured_until: nil, featured_by: nil)
      redirect_to admin_entry_path(@entry), notice: t("admin.entries.unfeatured")
    end

    def extend_expiry
      new_expiry = params[:expires_at] || @entry.expires_at&.+(30.days) || 30.days.from_now
      @entry.update!(expires_at: new_expiry)
      redirect_to admin_entry_path(@entry), notice: t("admin.entries.expiry_extended")
    end

    def unschedule
      @entry.update!(scheduled_for: nil)
      redirect_to admin_entry_path(@entry), notice: t("admin.entries.unscheduled")
    end

    def publish_now
      @entry.update!(published_at: Time.current, scheduled_for: nil)
      redirect_to admin_entry_path(@entry), notice: t("admin.entries.published_now")
    end

    # Moderation
    def hide
      authorize @entry, :hide?
      @entry.hide!(current_user)
      redirect_back fallback_location: admin_root_path, notice: t("admin.moderation.hidden")
    end

    def unhide
      authorize @entry, :unhide?
      @entry.unhide!
      redirect_back fallback_location: admin_root_path, notice: t("admin.moderation.unhidden")
    end

    def lock_comments
      authorize @entry, :lock_comments?
      @entry.lock_comments!(current_user)
      redirect_back fallback_location: admin_root_path, notice: t("admin.moderation.comments_locked")
    end

    def unlock_comments
      authorize @entry, :unlock_comments?
      @entry.unlock_comments!
      redirect_back fallback_location: admin_root_path, notice: t("admin.moderation.comments_unlocked")
    end

    def bulk_action
      authorize Entry, :bulk_action?

      ids = params[:entry_ids].to_s.split(",").map(&:to_i).reject(&:zero?)
      if ids.empty?
        redirect_to admin_entries_path, alert: t("admin.entries.no_items_selected")
        return
      end

      entries = base_scope.where(id: ids)
      count = entries.count

      case params[:bulk_action]
      when "publish"
        entries.update_all(published_at: Time.current)
        redirect_to admin_entries_path, notice: t("admin.entries.bulk_published", count: count)
      when "unpublish"
        entries.update_all(published_at: nil)
        redirect_to admin_entries_path, notice: t("admin.entries.bulk_unpublished", count: count)
      when "editorialise"
        entries.feed_items.find_each { |e| EditorialiseEntryJob.perform_later(e.id) }
        redirect_to admin_entries_path, notice: t("admin.entries.bulk_editorialise", count: count)
      when "enrich"
        BulkEnrichmentJob.perform_later(entry_ids: ids)
        redirect_to admin_entries_path, notice: t("admin.entries.bulk_enrich", count: count)
      when "delete"
        entries.destroy_all
        redirect_to admin_entries_path, notice: t("admin.entries.bulk_deleted", count: count)
      else
        redirect_to admin_entries_path, alert: t("admin.entries.unknown_action")
      end
    end

    private

    def base_scope
      Entry.without_site_scope.where(tenant: Current.tenant)
    end

    def set_entry
      @entry = Entry.includes(:category, :source, :site).find(params[:id])
    end

    def set_categories
      @categories = Category.without_tenant_scope.where(site: Current.site).order(:name)
    end

    def apply_status_filters
      case params[:status]
      when "published"
        @entries = @entries.published
      when "unpublished"
        @entries = @entries.where(published_at: nil)
      when "editorialised"
        @entries = @entries.where.not(editorialised_at: nil)
      when "not_editorialised"
        @entries = @entries.where(editorialised_at: nil)
      when "enrichment_pending"
        @entries = @entries.enrichment_pending
      when "enrichment_complete"
        @entries = @entries.enrichment_complete
      when "enrichment_failed"
        @entries = @entries.enrichment_failed
      end
    end

    def entry_params
      permitted = [
        :entry_kind, :title, :description, :url_raw, :url_canonical,
        :published_at, :scheduled_for, :category_id, :listing_type,
        :publish_action,
        :ai_summary, :why_it_matters, :content_type, :extracted_text,
        :topic_tags_string,
        :image_url, :site_name, :body_html, :body_text,
        :company, :location, :salary_range, :apply_url,
        :affiliate_url_template, :featured_from, :featured_until, :expires_at,
        :paid, :payment_reference,
        topic_tags: [], ai_suggested_tags: [],
        metadata: {}, affiliate_attribution: {}
      ]
      params.require(:entry).permit(permitted)
    end

    def apply_publish_action(entry, action, scheduled_for_value)
      case action
      when "publish"
        entry.published_at = Time.current
        entry.scheduled_for = nil
      when "schedule"
        entry.scheduled_for = scheduled_for_value.presence ? Time.zone.parse(scheduled_for_value) : nil
        entry.published_at = nil
      when "draft"
        entry.published_at = nil
        entry.scheduled_for = nil
      end
    end

    def build_stats
      base = @source ? Entry.feed_items.where(source: @source) : base_scope
      {
        total: base.count,
        published: base.published.count,
        unpublished: base.where(published_at: nil).count,
        editorialised: base.where.not(editorialised_at: nil).count,
        this_week: base.where("created_at > ?", 1.week.ago).count,
        enrichment_pending: base.respond_to?(:enrichment_pending) ? base.enrichment_pending.count : 0,
        enrichment_complete: base.respond_to?(:enrichment_complete) ? base.enrichment_complete.count : 0,
        enrichment_failed: base.respond_to?(:enrichment_failed) ? base.enrichment_failed.count : 0
      }
    end
  end
end
