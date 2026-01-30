# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  admin                  :boolean          default(FALSE), not null
#  avatar_url             :string
#  bio                    :text
#  display_name           :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  rolify

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations are automatically created by rolify
  has_many :votes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :site_bans, dependent: :destroy
  has_many :flags, dependent: :destroy
  has_many :reviewed_flags, class_name: "Flag", foreign_key: :reviewed_by_id, dependent: :nullify, inverse_of: :reviewed_by
  has_many :digest_subscriptions, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :content_views, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :admin, inclusion: { in: [ true, false ] }
  validates :display_name, length: { maximum: 50 }, allow_blank: true
  validates :bio, length: { maximum: 500 }, allow_blank: true
  validates :avatar_url, length: { maximum: 500 }, allow_blank: true

  # Scopes
  scope :admins, -> { where(admin: true) }

  # Instance methods
  def admin?
    admin == true
  end

  def has_tenant_role?(role_name, tenant)
    has_role?(role_name, tenant)
  end

  def can_access_tenant?(tenant)
    admin? || [ :owner, :admin, :editor, :viewer ].any? { |role| has_role?(role, tenant) }
  end

  def tenant_roles(tenant)
    roles.where(resource: tenant)
  end

  def highest_tenant_role(tenant)
    role_hierarchy = { owner: 4, admin: 3, editor: 2, viewer: 1 }
    tenant_roles(tenant).max_by { |role| role_hierarchy[role.name.to_sym] || 0 }
  end

  def banned_from?(site)
    site_bans.for_site(site).active.exists?
  end

  # Profile methods
  def profile_name
    display_name.presence || email.split("@").first
  end

  def initials
    name = profile_name
    words = name.split(/[\s_.-]+/)
    if words.length >= 2
      "#{words.first[0]}#{words.last[0]}".upcase
    else
      name[0..1].upcase
    end
  end
end
