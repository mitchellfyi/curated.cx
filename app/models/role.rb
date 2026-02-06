# frozen_string_literal: true

# == Schema Information
#
# Table name: roles
#
#  id            :bigint           not null, primary key
#  name          :string
#  resource_type :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  resource_id   :bigint
#
# Indexes
#
#  index_roles_on_name_and_resource_type_and_resource_id  (name,resource_type,resource_id)
#  index_roles_on_resource                                (resource_type,resource_id)
#
class Role < ApplicationRecord
  TENANT_ROLES = %w[owner admin editor viewer].freeze
  HIERARCHY = { "owner" => 4, "admin" => 3, "editor" => 2, "viewer" => 1 }.freeze

  has_and_belongs_to_many :users, join_table: :users_roles

  belongs_to :resource,
             polymorphic: true,
             optional: true

  validates :name, presence: true
  validates :resource_type,
            inclusion: { in: %w[Tenant] },
            allow_nil: true

  scopify

  # Class methods
  def self.tenant_roles
    where(resource_type: "Tenant")
  end

  def self.role_names
    TENANT_ROLES
  end

  # Instance methods
  def tenant_role?
    resource_type == "Tenant"
  end

  def role_level
    HIERARCHY[name] || 0
  end
end
