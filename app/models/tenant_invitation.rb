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
class TenantInvitation < ApplicationRecord
  belongs_to :tenant
  belongs_to :invited_by, class_name: "User"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true, inclusion: { in: Role::TENANT_ROLES }
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  scope :pending, -> { where(accepted_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where(accepted_at: nil).where("expires_at <= ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }

  def pending?
    accepted_at.nil? && expires_at > Time.current
  end

  def expired?
    accepted_at.nil? && expires_at <= Time.current
  end

  def accepted?
    accepted_at.present?
  end

  def accept!(user)
    return false if accepted? || expired?

    transaction do
      update!(accepted_at: Time.current)
      Role::TENANT_ROLES.each { |r| user.remove_role(r, tenant) }
      user.add_role(role.to_sym, tenant)
    end
    true
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at ||= 7.days.from_now
  end
end
