# frozen_string_literal: true

# == Schema Information
#
# Table name: tenant_invitations
#
#  id            :bigint           not null, primary key
#  accepted_at   :datetime
#  email         :string           not null
#  expires_at    :datetime         not null
#  role          :string           default("viewer"), not null
#  token         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  invited_by_id :bigint           not null
#  tenant_id     :bigint           not null
#
# Indexes
#
#  index_tenant_invitations_on_invited_by_id        (invited_by_id)
#  index_tenant_invitations_on_tenant_id            (tenant_id)
#  index_tenant_invitations_on_tenant_id_and_email  (tenant_id,email) UNIQUE WHERE (accepted_at IS NULL)
#  index_tenant_invitations_on_token                (token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (invited_by_id => users.id)
#  fk_rails_...  (tenant_id => tenants.id)
#
require "rails_helper"

RSpec.describe TenantInvitation, type: :model do
  let(:tenant) { create(:tenant, :ai_news) }
  let(:inviter) { create(:user, :admin) }

  describe "validations" do
    it "is valid with valid attributes" do
      invitation = build(:tenant_invitation, tenant: tenant, invited_by: inviter)
      expect(invitation).to be_valid
    end

    it "requires email" do
      invitation = build(:tenant_invitation, tenant: tenant, invited_by: inviter, email: nil)
      expect(invitation).not_to be_valid
    end

    it "requires valid email format" do
      invitation = build(:tenant_invitation, tenant: tenant, invited_by: inviter, email: "notanemail")
      expect(invitation).not_to be_valid
    end

    it "requires role to be a valid tenant role" do
      invitation = build(:tenant_invitation, tenant: tenant, invited_by: inviter, role: "superuser")
      expect(invitation).not_to be_valid
    end
  end

  describe "token generation" do
    it "generates a token on create" do
      invitation = create(:tenant_invitation, tenant: tenant, invited_by: inviter)
      expect(invitation.token).to be_present
    end
  end

  describe "expiry" do
    it "defaults to 7 days from now" do
      invitation = create(:tenant_invitation, tenant: tenant, invited_by: inviter)
      expect(invitation.expires_at).to be_within(1.minute).of(7.days.from_now)
    end
  end

  describe "#pending?" do
    it "returns true for active invitations" do
      invitation = create(:tenant_invitation, tenant: tenant, invited_by: inviter)
      expect(invitation.pending?).to be true
    end

    it "returns false for expired invitations" do
      invitation = create(:tenant_invitation, :expired, tenant: tenant, invited_by: inviter)
      expect(invitation.pending?).to be false
    end

    it "returns false for accepted invitations" do
      invitation = create(:tenant_invitation, :accepted, tenant: tenant, invited_by: inviter)
      expect(invitation.pending?).to be false
    end
  end

  describe "#accept!" do
    let(:invitation) { create(:tenant_invitation, tenant: tenant, invited_by: inviter, role: "editor") }
    let(:user) { create(:user) }

    it "marks the invitation as accepted" do
      invitation.accept!(user)
      expect(invitation.reload.accepted?).to be true
    end

    it "assigns the role to the user" do
      invitation.accept!(user)
      expect(user.has_role?(:editor, tenant)).to be true
    end

    it "returns false for expired invitations" do
      expired = create(:tenant_invitation, :expired, tenant: tenant, invited_by: inviter)
      expect(expired.accept!(user)).to be false
    end

    it "returns false for already accepted invitations" do
      accepted = create(:tenant_invitation, :accepted, tenant: tenant, invited_by: inviter)
      expect(accepted.accept!(user)).to be false
    end
  end

  describe "scopes" do
    let!(:pending_invite) { create(:tenant_invitation, tenant: tenant, invited_by: inviter) }
    let!(:expired_invite) { create(:tenant_invitation, :expired, tenant: tenant, invited_by: inviter) }
    let!(:accepted_invite) { create(:tenant_invitation, :accepted, tenant: tenant, invited_by: inviter) }

    it ".pending returns only pending invitations" do
      expect(TenantInvitation.pending).to include(pending_invite)
      expect(TenantInvitation.pending).not_to include(expired_invite, accepted_invite)
    end

    it ".accepted returns only accepted invitations" do
      expect(TenantInvitation.accepted).to include(accepted_invite)
      expect(TenantInvitation.accepted).not_to include(pending_invite, expired_invite)
    end
  end
end
