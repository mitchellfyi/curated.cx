# frozen_string_literal: true

class Admin::EditorialisationsController < ApplicationController
  include AdminAccess

  before_action :set_editorialisation, only: [ :show, :retry ]

  def index
    @editorialisations = base_scope
      .includes(:content_item)
      .recent
      .page(params[:page])
      .per(25)

    @editorialisations = @editorialisations.by_status(params[:status]) if params[:status].present?
  end

  def show
  end

  def retry
    if @editorialisation.failed? || @editorialisation.skipped?
      # Re-queue the editorialisation job
      EditorialiseContentItemJob.perform_later(@editorialisation.content_item_id)
      redirect_to admin_editorialisation_path(@editorialisation),
                  notice: t("admin.editorialisations.retrying")
    else
      redirect_to admin_editorialisation_path(@editorialisation),
                  alert: t("admin.editorialisations.cannot_retry")
    end
  end

  private

  def set_editorialisation
    @editorialisation = base_scope.find(params[:id])
  end

  def base_scope
    Editorialisation
  end
end
