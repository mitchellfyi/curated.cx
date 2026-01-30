# frozen_string_literal: true

class LiveStreamMailer < ApplicationMailer
  def stream_live_notification(subscription, stream)
    @subscription = subscription
    @stream = stream
    @user = subscription.user
    @site = subscription.site
    @tenant = @site.tenant

    mail(
      to: @user.email,
      subject: I18n.t("live_stream_mailer.stream_live_notification.subject",
                      site: @site.name,
                      title: @stream.title),
      from: notification_from_address
    )
  end

  private

  def notification_from_address
    site_email = @site.setting("email.from_address")
    return site_email if site_email.present?

    tenant_email = @tenant.setting("email.from_address")
    return tenant_email if tenant_email.present?

    "notifications@#{@site.primary_hostname || 'curated.cx'}"
  end
end
