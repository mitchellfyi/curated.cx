# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @bookmarks_count = current_user.bookmarks.count
    @submissions_count = Submission.where(user: current_user).count
    @purchases_count = Purchase.where(user: current_user).count
    @recent_bookmarks = current_user.bookmarks.includes(:bookmarkable).order(created_at: :desc).limit(5)
    @recent_purchases = Purchase.where(user: current_user).includes(:digital_product, :listing).order(created_at: :desc).limit(5)
  end
end
