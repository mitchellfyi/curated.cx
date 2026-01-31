# frozen_string_literal: true

class Admin::SubscriberSegmentsController < ApplicationController
  include AdminAccess

  before_action :set_subscriber_segment, only: %i[show edit update destroy preview]
  before_action :prevent_system_segment_modification, only: %i[edit update destroy]

  def index
    @subscriber_segments = SubscriberSegment.all.order(system_segment: :desc, name: :asc)
  end

  def show
    @subscribers_count = SegmentationService.subscribers_for(@subscriber_segment).count
    @sample_subscribers = SegmentationService.subscribers_for(@subscriber_segment).includes(:user).limit(10)
  end

  def new
    @subscriber_segment = SubscriberSegment.new
    @subscriber_tags = SubscriberTag.alphabetical
  end

  def create
    @subscriber_segment = SubscriberSegment.new(subscriber_segment_params)
    @subscriber_segment.site = Current.site

    if @subscriber_segment.save
      redirect_to admin_subscriber_segment_path(@subscriber_segment), notice: t("admin.subscriber_segments.created")
    else
      @subscriber_tags = SubscriberTag.alphabetical
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @subscriber_tags = SubscriberTag.alphabetical
  end

  def update
    if @subscriber_segment.update(subscriber_segment_params)
      redirect_to admin_subscriber_segment_path(@subscriber_segment), notice: t("admin.subscriber_segments.updated")
    else
      @subscriber_tags = SubscriberTag.alphabetical
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @subscriber_segment.destroy
    redirect_to admin_subscriber_segments_path, notice: t("admin.subscriber_segments.deleted")
  end

  def preview
    rules = build_rules_from_params
    preview_segment = SubscriberSegment.new(site: Current.site, rules: rules)
    count = SegmentationService.subscribers_for(preview_segment).count

    render json: { count: count }
  end

  private

  def set_subscriber_segment
    @subscriber_segment = SubscriberSegment.find(params[:id])
  end

  def prevent_system_segment_modification
    return unless @subscriber_segment.system_segment?

    redirect_to admin_subscriber_segments_path, alert: t("admin.subscriber_segments.system_protected")
  end

  def subscriber_segment_params
    params.require(:subscriber_segment).permit(:name, :description, :enabled).tap do |p|
      p[:rules] = build_rules_from_params
    end
  end

  def build_rules_from_params
    rules = {}
    rules_params = params[:subscriber_segment]&.dig(:rules) || params[:rules] || {}

    # Subscription age
    if rules_params[:subscription_age].present?
      age_rules = {}
      age_rules["min_days"] = rules_params[:subscription_age][:min_days].to_i if rules_params[:subscription_age][:min_days].present?
      age_rules["max_days"] = rules_params[:subscription_age][:max_days].to_i if rules_params[:subscription_age][:max_days].present?
      rules["subscription_age"] = age_rules if age_rules.any?
    end

    # Engagement level
    if rules_params[:engagement_level].present?
      eng_rules = {}
      eng_rules["min_actions"] = rules_params[:engagement_level][:min_actions].to_i if rules_params[:engagement_level][:min_actions].present?
      eng_rules["within_days"] = rules_params[:engagement_level][:within_days].to_i if rules_params[:engagement_level][:within_days].present?
      rules["engagement_level"] = eng_rules if eng_rules.any?
    end

    # Referral count
    if rules_params[:referral_count].present? && rules_params[:referral_count][:min].present?
      rules["referral_count"] = { "min" => rules_params[:referral_count][:min].to_i }
    end

    # Tags
    if rules_params[:tags].present?
      tag_rules = {}
      tag_rules["any"] = Array(rules_params[:tags][:any]).reject(&:blank?) if rules_params[:tags][:any].present?
      tag_rules["all"] = Array(rules_params[:tags][:all]).reject(&:blank?) if rules_params[:tags][:all].present?
      rules["tags"] = tag_rules if tag_rules.any?
    end

    # Frequency
    rules["frequency"] = rules_params[:frequency] if rules_params[:frequency].present?

    # Active
    if rules_params[:active].present? && rules_params[:active] != ""
      rules["active"] = ActiveModel::Type::Boolean.new.cast(rules_params[:active])
    end

    rules
  end
end
