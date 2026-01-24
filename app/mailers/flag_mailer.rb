# frozen_string_literal: true

class FlagMailer < ApplicationMailer
  def new_flag_notification(flag)
    @flag = flag
    @site = flag.site
    @flaggable = flag.flaggable
    @admin_emails = admin_emails_for_site(@site)

    return if @admin_emails.empty?

    mail(
      to: @admin_emails,
      subject: I18n.t("flag_mailer.new_flag_notification.subject", site_name: @site.name)
    )
  end

  private

  def admin_emails_for_site(site)
    tenant = site.tenant

    # Collect admin emails: global admins + tenant owners/admins
    admin_users = User.admins.pluck(:email)

    # Get tenant-level owners and admins
    tenant_admins = User.with_any_role({ name: :owner, resource: tenant }, { name: :admin, resource: tenant })
                        .pluck(:email)

    (admin_users + tenant_admins).uniq
  end
end
