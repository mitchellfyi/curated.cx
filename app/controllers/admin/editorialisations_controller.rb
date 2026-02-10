# frozen_string_literal: true

class Admin::EditorialisationsController < ApplicationController
  include AdminAccess

  before_action :set_editorialisation, only: [ :show, :retry ]

  def index
    @editorialisations = base_scope
      .includes(:entry)
      .recent
      .page(params[:page])
      .per(25)

    @editorialisations = @editorialisations.by_status(params[:status]) if params[:status].present?
    @stats = build_stats
  end

  def show
  end

  def retry
    if @editorialisation.failed? || @editorialisation.skipped?
      EditorialiseEntryJob.perform_later(@editorialisation.entry_id)
      redirect_to admin_editorialisation_path(@editorialisation),
                  notice: t("admin.editorialisations.retrying")
    else
      redirect_to admin_editorialisation_path(@editorialisation),
                  alert: t("admin.editorialisations.cannot_retry")
    end
  end

  # POST /admin/editorialisations/retry_failed
  def retry_failed
    failed = Editorialisation.by_status("failed").limit(50)
    count = 0

    failed.find_each do |ed|
      EditorialiseEntryJob.perform_later(ed.entry_id)
      count += 1
    end

    redirect_to admin_editorialisations_path(status: "failed"),
                notice: "Queued #{count} failed editorialisations for retry."
  end

  private

  def set_editorialisation
    @editorialisation = base_scope.find(params[:id])
  end

  def base_scope
    Editorialisation
  end

  def build_stats
    {
      total: Editorialisation.count,
      completed: Editorialisation.by_status("completed").count,
      pending: Editorialisation.by_status("pending").count,
      processing: Editorialisation.by_status("processing").count,
      failed: Editorialisation.by_status("failed").count,
      skipped: Editorialisation.by_status("skipped").count,
      tokens_today: Editorialisation.where("created_at > ?", Time.current.beginning_of_day).sum(:tokens_used),
      today_count: Editorialisation.where("created_at > ?", Time.current.beginning_of_day).count
    }
  rescue
    {}
  end
end
