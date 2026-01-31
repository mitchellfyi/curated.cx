# frozen_string_literal: true

class Admin::SubscriberTagsController < ApplicationController
  include AdminAccess

  before_action :set_subscriber_tag, only: %i[show edit update destroy]

  def index
    @subscriber_tags = SubscriberTag.alphabetical
  end

  def show
  end

  def new
    @subscriber_tag = SubscriberTag.new
  end

  def create
    @subscriber_tag = SubscriberTag.new(subscriber_tag_params)
    @subscriber_tag.site = Current.site

    if @subscriber_tag.save
      redirect_to admin_subscriber_tags_path, notice: t("admin.subscriber_tags.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @subscriber_tag.update(subscriber_tag_params)
      redirect_to admin_subscriber_tags_path, notice: t("admin.subscriber_tags.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @subscriber_tag.destroy
    redirect_to admin_subscriber_tags_path, notice: t("admin.subscriber_tags.deleted")
  end

  private

  def set_subscriber_tag
    @subscriber_tag = SubscriberTag.find_by!(slug: params[:id])
  end

  def subscriber_tag_params
    params.require(:subscriber_tag).permit(:name)
  end
end
