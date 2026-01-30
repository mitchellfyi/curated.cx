# frozen_string_literal: true

class DiscussionsController < ApplicationController
  include RateLimitable
  include BanCheckable

  before_action :authenticate_user!, except: %i[index show]
  before_action :check_discussions_enabled, only: %i[new create]
  before_action :set_discussion, only: %i[show update destroy]
  before_action :check_ban_status, only: %i[create update]

  # GET /discussions
  def index
    @discussions = policy_scope(Discussion)
                   .pinned_first
                   .includes(:user)

    authorize Discussion
  end

  # GET /discussions/:id
  def show
    authorize @discussion

    @posts = @discussion.posts
                        .root_posts
                        .visible
                        .includes(:user, replies: :user)
                        .oldest_first
    @new_post = @discussion.posts.build
  end

  # GET /discussions/new
  def new
    @discussion = Discussion.new(visibility: Current.site.discussions_default_visibility)
    authorize @discussion
  end

  # POST /discussions
  def create
    @discussion = Current.site.discussions.build(discussion_params)
    @discussion.user = current_user

    authorize @discussion

    if rate_limited?(current_user, :discussion, **RateLimitable::LIMITS[:discussion])
      return render_rate_limited(message: I18n.t("discussions.rate_limited"))
    end

    if @discussion.save
      track_action(current_user, :discussion)
      respond_to do |format|
        format.html { redirect_to @discussion, notice: I18n.t("discussions.created") }
        format.turbo_stream
        format.json { render json: @discussion, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @discussion.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /discussions/:id
  def update
    authorize @discussion

    if @discussion.update(discussion_params)
      respond_to do |format|
        format.html { redirect_to @discussion, notice: I18n.t("discussions.updated") }
        format.turbo_stream
        format.json { render json: @discussion }
      end
    else
      respond_to do |format|
        format.html { render :show, status: :unprocessable_entity }
        format.json { render json: { errors: @discussion.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /discussions/:id
  def destroy
    authorize @discussion
    @discussion.destroy

    respond_to do |format|
      format.html { redirect_to discussions_path, notice: I18n.t("discussions.deleted") }
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private

  def set_discussion
    @discussion = Discussion.find(params[:id])
  end

  def discussion_params
    permitted = %i[title body]
    permitted << :visibility if admin_or_owner?
    params.require(:discussion).permit(permitted)
  end

  def check_discussions_enabled
    return if Current.site&.discussions_enabled?

    respond_to do |format|
      format.html { redirect_to root_path, alert: I18n.t("discussions.disabled") }
      format.json { render json: { error: I18n.t("discussions.disabled") }, status: :forbidden }
    end
  end

  def admin_or_owner?
    return true if current_user&.admin?
    return false unless Current.tenant && current_user

    current_user.has_role?(:owner, Current.tenant) || current_user.has_role?(:admin, Current.tenant)
  end
end
