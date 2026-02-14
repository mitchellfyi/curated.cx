# frozen_string_literal: true

module Admin
  class BusinessClaimsController < ApplicationController
    include AdminAccess

    before_action :set_claim, only: %i[show verify reject]

    def index
      @claims = BusinessClaim.joins(:entry)
                             .where(entries: { site_id: Current.site&.id })
                             .includes(:entry, :user)
                             .recent
                             .page(params[:page]).per(25)

      @claims = @claims.where(status: params[:status]) if params[:status].present?

      calculate_stats
    end

    def show
    end

    def verify
      @claim.verify!
      redirect_to admin_business_claim_path(@claim), notice: "Business claim verified."
    end

    def reject
      @claim.reject!
      redirect_to admin_business_claim_path(@claim), notice: "Business claim rejected."
    end

    private

    def set_claim
      @claim = BusinessClaim.joins(:entry)
                            .where(entries: { site_id: Current.site&.id })
                            .find(params[:id])
    end

    def calculate_stats
      scope = BusinessClaim.joins(:entry).where(entries: { site_id: Current.site&.id })
      @total_claims = scope.count
      @pending_claims = scope.pending.count
      @verified_claims = scope.verified.count
      @rejected_claims = scope.rejected.count
    end
  end
end
