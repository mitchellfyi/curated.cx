require 'rails_helper'

RSpec.describe UserDecorator, type: :decorator do
  let(:user) { create(:user, email: 'john.doe@example.com') }
  let(:decorated_user) { user.decorate }

  describe '#display_name' do
    it 'returns humanized email username' do
      expect(decorated_user.display_name).to eq('John.doe')
    end
  end

  describe '#full_display_name' do
    it 'returns the display name' do
      expect(decorated_user.full_display_name).to eq(decorated_user.display_name)
    end
  end

  describe '#avatar_image' do
    context 'when user has no avatar_url' do
      it 'returns avatar placeholder' do
        result = decorated_user.avatar_image(size: 40)
        expect(result).to include('rounded-full')
        expect(result).to include('J')  # First initial
      end
    end

    context 'when user has avatar_url' do
      before { allow(decorated_user).to receive(:avatar_url).and_return('https://example.com/avatar.jpg') }

      it 'returns avatar image tag' do
        result = decorated_user.avatar_image(size: 40)
        expect(result).to include('img')
        expect(result).to include('avatar.jpg')
      end
    end
  end

  describe '#role_badges_for_tenant' do
    let(:tenant) { create(:tenant) }

    context 'when user has roles' do
      before { user.add_role(:editor, tenant) }

      it 'returns array of role badges' do
        badges = decorated_user.role_badges_for_tenant(tenant)
        expect(badges).to be_an(Array)
        expect(badges.first).to include('Editor')
        expect(badges.first).to include('rounded-full')
      end
    end

    context 'when user has no roles' do
      it 'returns empty array' do
        badges = decorated_user.role_badges_for_tenant(tenant)
        expect(badges).to eq([])
      end
    end
  end

  describe '#highest_role_badge_for_tenant' do
    let(:tenant) { create(:tenant) }

    context 'when user has roles' do
      before do
        user.add_role(:viewer, tenant)
        user.add_role(:admin, tenant)
      end

      it 'returns badge for highest role' do
        badge = decorated_user.highest_role_badge_for_tenant(tenant)
        expect(badge).to include('Admin')
        expect(badge).to include('bg-blue-100')
      end
    end

    context 'when user has no roles' do
      it 'returns nil' do
        badge = decorated_user.highest_role_badge_for_tenant(tenant)
        expect(badge).to be_nil
      end
    end
  end

  describe '#admin_badge' do
    context 'when user is admin' do
      let(:user) { create(:user, admin: true) }

      it 'returns admin badge' do
        badge = decorated_user.admin_badge
        expect(badge).to include('Admin')
        expect(badge).to include('bg-red-100')
      end
    end

    context 'when user is not admin' do
      it 'returns nil' do
        badge = decorated_user.admin_badge
        expect(badge).to be_nil
      end
    end
  end

  describe '#platform_admin_badge' do
    context 'when user is admin' do
      let(:user) { create(:user, admin: true) }

      it 'returns admin badge' do
        badge = decorated_user.platform_admin_badge
        expect(badge).to include('Platform Admin')
        expect(badge).to include('bg-red-100')
      end
    end

    context 'when user is not admin' do
      it 'returns nil' do
        badge = decorated_user.platform_admin_badge
        expect(badge).to be_nil
      end
    end
  end

  describe '#account_status' do
    context 'when user is admin' do
      let(:user) { create(:user, admin: true) }

      it 'returns admin status' do
        status = decorated_user.account_status
        expect(status).to include('Admin')
        expect(status).to include('text-red-600')
      end
    end

    context 'when user is regular user' do
      it 'returns user status' do
        status = decorated_user.account_status
        expect(status).to include('User')
        expect(status).to include('text-gray-600')
      end
    end
  end

  describe '#last_seen' do
    context 'when user has never signed in' do
      it 'returns "Never"' do
        expect(decorated_user.last_seen).to eq('Never')
      end
    end
  end

  describe '#member_since' do
    it 'returns formatted creation date' do
      member_since = decorated_user.member_since
      expect(member_since).to be_present
      expect(member_since).to include('ago')
    end
  end

  describe '#user_aria_label' do
    it 'returns proper aria label' do
      expect(decorated_user.user_aria_label).to eq('User John.doe')
    end
  end
end
