# frozen_string_literal: true

module My
  class PurchasesController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :authenticate_user!
    before_action :set_purchase, only: %i[show regenerate_token]

    # GET /my/purchases
    def index
      @purchases = Purchase.where(user: current_user)
                           .or(Purchase.where(email: current_user.email))
                           .includes(:digital_product, :download_tokens)
                           .recent
    end

    # GET /my/purchases/:id
    def show
      @download_token = @purchase.download_tokens.order(created_at: :desc).first
    end

    # POST /my/purchases/:id/regenerate_token
    def regenerate_token
      # Create a new download token
      new_token = DownloadToken.create!(purchase: @purchase)

      redirect_to my_purchase_path(@purchase), notice: t("my.purchases.token_regenerated")
    end

    private

    def set_purchase
      @purchase = Purchase.where(user: current_user)
                          .or(Purchase.where(email: current_user.email))
                          .find(params[:id])
    end
  end
end
