# frozen_string_literal: true

class SequenceMailer < ApplicationMailer
  def step_email(sequence_email)
    @sequence_email = sequence_email
    @step = sequence_email.email_step
    @enrollment = sequence_email.sequence_enrollment
    @subscription = @enrollment.digest_subscription
    @user = @subscription.user
    @site = @enrollment.email_sequence.site
    @tenant = @site.tenant

    # Don't send if subscription is no longer active
    return if !@subscription.active?

    mail(
      to: @user.email,
      subject: @step.subject,
      from: mailer_from_address
    )
  end

  private

  def mailer_from_address
    site_email = @site.setting("email.from_address")
    return site_email if site_email.present?

    tenant_email = @tenant.setting("email.from_address")
    return tenant_email if tenant_email.present?

    "sequence@#{@site.primary_hostname || 'curated.cx'}"
  end
end
