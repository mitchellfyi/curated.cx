# frozen_string_literal: true

class Admin::FlagsController < ApplicationController
  include AdminAccess

  before_action :set_flag, only: %i[show resolve dismiss]

  # GET /admin/flags
  def index
    @flags = Flag.for_site(Current.site).pending.includes(:user, :flaggable).recent
    @resolved_flags = Flag.for_site(Current.site).resolved.includes(:user, :flaggable, :reviewed_by).recent.limit(20)
  end

  # GET /admin/flags/:id
  def show
  end

  # POST /admin/flags/:id/resolve
  def resolve
    @flag.resolve!(current_user, action: :action_taken)

    respond_to do |format|
      format.html { redirect_to admin_flags_path, notice: I18n.t("admin.flags.resolved") }
      format.turbo_stream
    end
  end

  # POST /admin/flags/:id/dismiss
  def dismiss
    @flag.dismiss!(current_user)

    respond_to do |format|
      format.html { redirect_to admin_flags_path, notice: I18n.t("admin.flags.dismissed") }
      format.turbo_stream
    end
  end

  private

  def set_flag
    @flag = Flag.for_site(Current.site).find(params[:id])
  end
end
