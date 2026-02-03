# frozen_string_literal: true

class Admin::SubmissionsController < ApplicationController
  include AdminAccess

  before_action :set_submission, only: [ :show, :approve, :reject ]

  def index
    @status = params[:status] || "pending"
    @submissions = Submission
                             .then { |s| @status == "all" ? s : s.where(status: @status) }
                             .includes(:user, :category)
                             .order(created_at: :asc)
                             .limit(100)

    @stats = {
      pending: Submission.pending.count,
      approved: Submission.approved.count,
      rejected: Submission.rejected.count
    }

    set_page_meta_tags(
      title: t("admin.submissions.title"),
      description: t("admin.submissions.description")
    )
  end

  def show
    set_page_meta_tags(
      title: t("admin.submissions.show.title", title: @submission.title),
      description: t("admin.submissions.show.description")
    )
  end

  def approve
    listing = @submission.approve!(reviewer: current_user, notes: params[:notes])

    respond_to do |format|
      format.html { redirect_to admin_submissions_path, notice: t("admin.submissions.approved", title: @submission.title) }
      format.turbo_stream do
        flash.now[:notice] = t("admin.submissions.approved", title: @submission.title)
      end
    end
  end

  def reject
    @submission.reject!(reviewer: current_user, notes: params[:notes])

    respond_to do |format|
      format.html { redirect_to admin_submissions_path, notice: t("admin.submissions.rejected", title: @submission.title) }
      format.turbo_stream do
        flash.now[:notice] = t("admin.submissions.rejected", title: @submission.title)
      end
    end
  end

  private

  def set_submission
    @submission = Submission.find(params[:id])
  end
end
