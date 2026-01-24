# frozen_string_literal: true

require "rails_helper"

RSpec.describe FlagMailer, type: :mailer do
  let(:tenant) { create(:tenant) }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }
  let(:source) { create(:source, site: site) }
  let(:content_item) { create(:content_item, site: site, source: source) }
  let(:comment_owner) { create(:user) }
  let(:comment) { create(:comment, content_item: content_item, user: comment_owner, site: site) }
  let(:flagger) { create(:user) }
  let(:admin) { create(:user, admin: true) }
  let(:tenant_owner) { create(:user).tap { |u| u.add_role(:owner, tenant) } }

  before do
    allow(Current).to receive(:site).and_return(site)
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe "#new_flag_notification" do
    context "when flagging a content item" do
      let(:flag) { create(:flag, flaggable: content_item, user: flagger, site: site, reason: :spam) }

      before do
        admin # ensure admin exists
        tenant_owner # ensure tenant owner exists
      end

      it "sends an email" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.subject).to include(site.name)
        expect(mail.subject).to include("New content flagged")
      end

      it "sends to admin emails" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.to).to include(admin.email)
        expect(mail.to).to include(tenant_owner.email)
      end

      it "includes flag reason in the body" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.body.encoded).to include(I18n.t("flags.reasons.spam"))
      end

      it "includes flagger email in the body" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.body.encoded).to include(flagger.email)
      end

      it "includes content item title" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.body.encoded).to include(content_item.title)
      end

      it "includes link to admin moderation queue" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.body.encoded).to include("admin/flags")
      end
    end

    context "when flagging a comment" do
      let(:flag) { create(:flag, flaggable: comment, user: flagger, site: site, reason: :harassment) }

      before do
        admin
      end

      it "sends an email" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.subject).to include("New content flagged")
      end

      it "includes comment body in the email" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.body.encoded).to include(comment.body)
      end

      it "includes comment author email" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.body.encoded).to include(comment_owner.email)
      end
    end

    context "when flag has details" do
      let(:flag) { create(:flag, :with_details, flaggable: content_item, user: flagger, site: site) }

      before do
        admin
      end

      it "includes the details in the email" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.body.encoded).to include(flag.details)
      end
    end

    context "when no admins exist" do
      let(:flag) { create(:flag, flaggable: content_item, user: flagger, site: site) }

      it "does not send an email" do
        mail = described_class.new_flag_notification(flag)

        expect(mail.to).to be_nil
      end
    end

    context "deduplicates admin emails" do
      let(:flag) { create(:flag, flaggable: content_item, user: flagger, site: site) }
      let(:global_and_tenant_admin) { create(:user, admin: true) }

      before do
        global_and_tenant_admin.add_role(:admin, tenant)
      end

      it "sends to unique emails only" do
        mail = described_class.new_flag_notification(flag)

        # Email should appear only once even if user is both global and tenant admin
        expect(mail.to.count(global_and_tenant_admin.email)).to eq(1)
      end
    end
  end
end
