# frozen_string_literal: true

module Admin
  class InvitationsController < ApplicationController
    include AdminAccess

    before_action :require_admin_or_owner
    before_action :set_invitation, only: [ :destroy, :resend ]

    def index
      @pending = TenantInvitation.where(tenant: Current.tenant).pending.order(created_at: :desc)
      @accepted = TenantInvitation.where(tenant: Current.tenant).accepted.order(accepted_at: :desc).limit(20)
    end

    def create
      @invitation = TenantInvitation.new(invitation_params)
      @invitation.tenant = Current.tenant
      @invitation.invited_by = current_user

      if @invitation.save
        TenantInvitationMailer.invite(@invitation).deliver_later
        redirect_to admin_invitations_path, notice: "Invitation sent to #{@invitation.email}."
      else
        @pending = TenantInvitation.where(tenant: Current.tenant).pending.order(created_at: :desc)
        @accepted = TenantInvitation.where(tenant: Current.tenant).accepted.order(accepted_at: :desc).limit(20)
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      @invitation.destroy
      redirect_to admin_invitations_path, notice: "Invitation cancelled."
    end

    def resend
      if @invitation.pending?
        TenantInvitationMailer.invite(@invitation).deliver_later
        redirect_to admin_invitations_path, notice: "Invitation resent to #{@invitation.email}."
      else
        redirect_to admin_invitations_path, alert: "Cannot resend expired or accepted invitation."
      end
    end

    private

    def set_invitation
      @invitation = TenantInvitation.where(tenant: Current.tenant).find(params[:id])
    end

    def require_admin_or_owner
      return if current_user&.admin?
      return if Current.tenant && %i[owner admin].any? { |r| current_user&.has_role?(r, Current.tenant) }

      redirect_to admin_root_path, alert: "Only admins can manage invitations."
    end

    def invitation_params
      params.require(:tenant_invitation).permit(:email, :role)
    end
  end
end
