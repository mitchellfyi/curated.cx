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
require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_inclusion_of(:resource_type).in_array(%w[Tenant]).allow_nil }
  end

  describe 'associations' do
    it { should have_and_belong_to_many(:users) }
    it { should belong_to(:resource).optional }
  end

  describe 'scopes' do
    let!(:tenant_role) { create(:role, resource_type: 'Tenant') }
    let!(:other_role) { create(:role, :global) }

    describe '.tenant_roles' do
      it 'returns only roles with Tenant resource type' do
        expect(Role.tenant_roles).to include(tenant_role)
        expect(Role.tenant_roles).not_to include(other_role)
      end
    end
  end

  describe 'constants' do
    it 'defines TENANT_ROLES' do
      expect(Role::TENANT_ROLES).to eq(%w[owner admin editor viewer])
    end

    it 'defines HIERARCHY' do
      expect(Role::HIERARCHY).to eq({ "owner" => 4, "admin" => 3, "editor" => 2, "viewer" => 1 })
    end

    it 'freezes TENANT_ROLES' do
      expect(Role::TENANT_ROLES).to be_frozen
    end
  end

  describe '.role_names' do
    it 'returns the expected role names' do
      expect(Role.role_names).to eq(%w[owner admin editor viewer])
    end
  end

  describe '#tenant_role?' do
    it 'returns true for Tenant resource type' do
      role = build(:role, resource_type: 'Tenant')
      expect(role.tenant_role?).to be true
    end

    it 'returns false for other resource types' do
      role = build(:role, :global)
      expect(role.tenant_role?).to be false
    end
  end

  describe '#role_level' do
    it 'returns correct level for owner role' do
      role = build(:role, name: 'owner')
      expect(role.role_level).to eq(4)
    end

    it 'returns correct level for admin role' do
      role = build(:role, name: 'admin')
      expect(role.role_level).to eq(3)
    end

    it 'returns correct level for editor role' do
      role = build(:role, name: 'editor')
      expect(role.role_level).to eq(2)
    end

    it 'returns correct level for viewer role' do
      role = build(:role, name: 'viewer')
      expect(role.role_level).to eq(1)
    end

    it 'returns 0 for unknown role' do
      role = build(:role, name: 'unknown')
      expect(role.role_level).to eq(0)
    end
  end
end
