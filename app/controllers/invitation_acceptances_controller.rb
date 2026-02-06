# frozen_string_literal: true

class InvitationAcceptancesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  before_action :set_invitation

  def show
    if @invitation.accepted?
      redirect_to root_path, notice: "This invitation has already been accepted."
    elsif @invitation.expired?
      redirect_to root_path, alert: "This invitation has expired."
    end
    # Otherwise render the acceptance page
  end

  def update
    if @invitation.expired?
      redirect_to root_path, alert: "This invitation has expired."
      return
    end

    if @invitation.accepted?
      redirect_to root_path, notice: "This invitation has already been accepted."
      return
    end

    unless user_signed_in?
      # Store invitation token and redirect to sign up/in
      session[:pending_invitation_token] = @invitation.token
      redirect_to new_user_registration_path, notice: "Please sign up or sign in to accept this invitation."
      return
    end

    if @invitation.accept!(current_user)
      redirect_to admin_root_path, notice: "Welcome to #{@invitation.tenant.title}! You've been granted #{@invitation.role.titleize} access."
    else
      redirect_to root_path, alert: "Could not accept invitation."
    end
  end

  private

  def set_invitation
    @invitation = TenantInvitation.find_by!(token: params[:token])
  end
end
