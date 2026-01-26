# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  admin                  :boolean          default(FALSE), not null
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
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'associations' do
    it { should have_and_belong_to_many(:roles) }
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe 'rolify integration' do
    it 'responds to rolify methods' do
      user = build(:user)
      expect(user).to respond_to(:has_role?)
      expect(user).to respond_to(:add_role)
      expect(user).to respond_to(:remove_role)
      expect(user).to respond_to(:has_any_role?)
    end
  end

  describe '#admin?' do
    it 'returns true when admin is true' do
      user = build(:user, admin: true)
      expect(user.admin?).to be true
    end

    it 'returns false when admin is false' do
      user = build(:user, admin: false)
      expect(user.admin?).to be false
    end
  end

  describe '#has_tenant_role?' do
    let(:user) { create(:user) }
    let(:tenant) { create(:tenant) }

    it 'returns true when user has the role on the tenant' do
      user.add_role(:owner, tenant)
      expect(user.has_tenant_role?(:owner, tenant)).to be true
    end

    it 'returns false when user does not have the role on the tenant' do
      expect(user.has_tenant_role?(:owner, tenant)).to be false
    end
  end

  describe '#can_access_tenant?' do
    let(:user) { create(:user) }
    let(:tenant) { create(:tenant) }

    it 'returns true for admins' do
      admin = create(:user, admin: true)
      expect(admin.can_access_tenant?(tenant)).to be true
    end

    it 'returns true when user has any tenant role' do
      user.add_role(:viewer, tenant)
      expect(user.can_access_tenant?(tenant)).to be true
    end

    it 'returns false when user has no tenant role' do
      expect(user.can_access_tenant?(tenant)).to be false
    end
  end

  describe '#tenant_roles' do
    let(:user) { create(:user) }
    let(:tenant) { create(:tenant) }

    it 'returns roles for the specific tenant' do
      user.add_role(:owner, tenant)
      user.add_role(:admin, tenant)

      roles = user.tenant_roles(tenant)
      expect(roles.count).to eq(2)
      expect(roles.map(&:name)).to contain_exactly('owner', 'admin')
    end
  end

  describe '#highest_tenant_role' do
    let(:user) { create(:user) }
    let(:tenant) { create(:tenant) }

    it 'returns the highest role by hierarchy' do
      user.add_role(:viewer, tenant)
      user.add_role(:admin, tenant)

      highest_role = user.highest_tenant_role(tenant)
      expect(highest_role.name).to eq('admin')
    end

    it 'returns owner as highest role' do
      user.add_role(:viewer, tenant)
      user.add_role(:owner, tenant)

      highest_role = user.highest_tenant_role(tenant)
      expect(highest_role.name).to eq('owner')
    end
  end
end
