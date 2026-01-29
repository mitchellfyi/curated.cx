# frozen_string_literal: true

class SubmissionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_submission, only: [ :show ]

  # Rate limit submissions per user
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { redirect_to new_submission_path, alert: t("submissions.rate_limited") }

  def index
    authorize Submission
    @submissions = policy_scope(Submission).by_user(current_user).recent.limit(50)

    set_page_meta_tags(
      title: t("submissions.index.title"),
      description: t("submissions.index.description")
    )
  end

  def show
    authorize @submission

    set_page_meta_tags(
      title: t("submissions.show.title", title: @submission.title),
      description: t("submissions.show.description")
    )
  end

  def new
    @submission = Submission.new
    authorize @submission
    @categories = Category.where(site: Current.site).order(:name)

    set_page_meta_tags(
      title: t("submissions.new.title"),
      description: t("submissions.new.description")
    )
  end

  def create
    @submission = Submission.new(submission_params)
    @submission.user = current_user
    @submission.site = Current.site
    @submission.ip_address = request.remote_ip
    authorize @submission

    if @submission.save
      redirect_to submissions_path, notice: t("submissions.created")
    else
      @categories = Category.where(site: Current.site).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_submission
    @submission = Submission.find(params[:id])
  end

  def submission_params
    params.require(:submission).permit(:url, :title, :description, :category_id, :listing_type)
  end
end
