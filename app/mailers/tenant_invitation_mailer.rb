# frozen_string_literal: true

class TenantInvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @tenant = invitation.tenant
    @accept_url = accept_invitation_url(token: invitation.token, host: @tenant.hostname)

    mail(
      to: invitation.email,
      subject: "You've been invited to #{@tenant.title}"
    )
  end
end
