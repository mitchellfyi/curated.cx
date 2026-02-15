# frozen_string_literal: true

module Admin
  class SponsorshipsController < ApplicationController
    include AdminAccess

    before_action :set_sponsorship, only: %i[show edit update destroy approve pause complete reject]

    def index
      @sponsorships = base_scope.includes(:entry, :user).recent.page(params[:page]).per(25)

      if params[:status].present?
        @sponsorships = @sponsorships.where(status: params[:status])
      end

      if params[:placement_type].present?
        @sponsorships = @sponsorships.where(placement_type: params[:placement_type])
      end

      calculate_stats
    end

    def show
    end

    def new
      @sponsorship = Sponsorship.new(site: Current.site)
    end

    def create
      @sponsorship = Sponsorship.new(sponsorship_params)
      @sponsorship.site = Current.site

      if @sponsorship.save
        redirect_to admin_sponsorship_path(@sponsorship), notice: "Sponsorship created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @sponsorship.update(sponsorship_params)
        redirect_to admin_sponsorship_path(@sponsorship), notice: "Sponsorship updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @sponsorship.destroy
      redirect_to admin_sponsorships_path, notice: "Sponsorship deleted."
    end

    def approve
      @sponsorship.approve!
      redirect_to admin_sponsorship_path(@sponsorship), notice: "Sponsorship approved and activated."
    end

    def pause
      @sponsorship.pause!
      redirect_to admin_sponsorship_path(@sponsorship), notice: "Sponsorship paused."
    end

    def complete
      @sponsorship.complete!
      redirect_to admin_sponsorship_path(@sponsorship), notice: "Sponsorship marked as completed."
    end

    def reject
      @sponsorship.reject!
      redirect_to admin_sponsorship_path(@sponsorship), notice: "Sponsorship rejected."
    end

    private

    def set_sponsorship
      @sponsorship = base_scope.includes(:entry, :user).find(params[:id])
    end

    def base_scope
      Sponsorship.where(site: Current.site)
    end

    def sponsorship_params
      params.require(:sponsorship).permit(
        :entry_id, :user_id, :placement_type, :category_slug,
        :starts_at, :ends_at, :budget_cents, :status
      )
    end

    def calculate_stats
      scope = base_scope
      @total_sponsorships = scope.count
      @active_sponsorships = scope.active.count
      @pending_sponsorships = scope.pending.count
      @total_impressions = scope.sum(:impressions)
      @total_clicks = scope.sum(:clicks)
      @total_budget = scope.sum(:budget_cents)
    end
  end
end
