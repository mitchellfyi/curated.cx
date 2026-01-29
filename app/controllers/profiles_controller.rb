# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :authenticate_user!, only: [ :edit, :update ]
  skip_after_action :verify_policy_scoped

  def show
    @user = User.find(params[:id])
    authorize @user, :show_profile?

    @comments = @user.comments
                     .includes(:content_item)
                     .where(content_items: { site_id: Current.site&.id })
                     .order(created_at: :desc)
                     .limit(20)

    @votes = @user.votes
                  .includes(:content_item)
                  .where(content_items: { site_id: Current.site&.id })
                  .order(created_at: :desc)
                  .limit(20)

    set_profile_meta_tags
  end

  def edit
    @user = User.find(params[:id])
    authorize @user, :edit_profile?
  end

  def update
    @user = User.find(params[:id])
    authorize @user, :update_profile?

    if @user.update(profile_params)
      redirect_to profile_path(@user), notice: t("profiles.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:display_name, :bio, :avatar_url)
  end

  def set_profile_meta_tags
    set_page_meta_tags(
      title: t("profiles.title", name: @user.profile_name),
      description: @user.bio.presence || t("profiles.default_description", name: @user.profile_name),
      robots: "noindex, follow"
    )
  end
end
