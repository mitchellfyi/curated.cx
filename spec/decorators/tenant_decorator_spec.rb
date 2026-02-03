require 'rails_helper'

RSpec.describe TenantDecorator, type: :decorator do
  let(:tenant) { create(:tenant,
    title: 'Test Tenant',
    description: 'Test description',
    hostname: 'test.example.com',
    slug: 'test',
    settings: {
      'theme' => {
        'primary_color' => 'blue',
        'secondary_color' => 'gray'
      }
    }
  )}
  let(:decorated_tenant) { tenant.decorate }

  describe '#display_name' do
    it 'returns tenant title' do
      expect(decorated_tenant.display_name).to eq('Test Tenant')
    end

    context 'when title is blank' do
      before { allow(tenant).to receive(:title).and_return('') }

      it 'returns hostname as fallback' do
        expect(decorated_tenant.display_name).to eq('test.example.com')
      end
    end
  end

  describe '#display_description' do
    it 'returns tenant description' do
      expect(decorated_tenant.display_description).to eq('Test description')
    end

    context 'when description is blank' do
      before { allow(tenant).to receive(:description).and_return('') }

      it 'returns default description' do
        expect(decorated_tenant.display_description).to eq('Content curated for Test Tenant')
      end
    end
  end

  describe '#logo_image' do
    context 'when tenant has logo_url' do
      before { tenant.update!(logo_url: 'https://example.com/logo.png') }

      it 'returns logo image tag' do
        result = decorated_tenant.logo_image(size: 40)
        expect(result).to include('img')
        expect(result).to include('logo.png')
        expect(result).to include('Test Tenant logo')
      end
    end

    context 'when tenant has no logo_url' do
      before { allow(tenant).to receive(:logo_url).and_return(nil) }

      it 'returns logo placeholder' do
        result = decorated_tenant.logo_image(size: 40)
        expect(result).to include('tenant-logo-placeholder')
        expect(result).to include('TT') # Initials
      end
    end
  end

  describe '#status_badge' do
    context 'when status is enabled' do
      before { tenant.update!(status: 'enabled') }

      it 'returns success badge' do
        badge = decorated_tenant.status_badge
        expect(badge).to include('Enabled')
        expect(badge).to include('bg-green')
      end
    end

    context 'when status is disabled' do
      before { tenant.update!(status: 'disabled') }

      it 'returns disabled badge' do
        badge = decorated_tenant.status_badge
        expect(badge).to include('Disabled')
        expect(badge).to include('bg-gray')
      end
    end
  end

  describe '#enabled_categories_list' do
    context 'when categories are enabled' do
      before { allow(tenant).to receive(:enabled_categories).and_return([ 'news', 'apps' ]) }

      it 'returns humanized list' do
        expect(decorated_tenant.enabled_categories_list).to eq('News and Apps')
      end
    end

    context 'when no categories enabled' do
      before { allow(tenant).to receive(:enabled_categories).and_return([]) }

      it 'returns "None"' do
        expect(decorated_tenant.enabled_categories_list).to eq('None')
      end
    end
  end

  describe '#absolute_url' do
    it 'returns base URL without path' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect(decorated_tenant.absolute_url).to eq('https://test.example.com')
    end

    it 'returns URL with path in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect(decorated_tenant.absolute_url('/admin')).to eq('https://test.example.com/admin')
    end

    it 'handles path with leading slash' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect(decorated_tenant.absolute_url('admin')).to eq('https://test.example.com/admin')
    end

    it 'returns localhost subdomain URL in development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      expect(decorated_tenant.absolute_url).to eq('http://test.localhost:3000')
    end

    it 'returns localhost subdomain URL with path in development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      expect(decorated_tenant.absolute_url('/admin')).to eq('http://test.localhost:3000/admin')
    end
  end

  describe '#admin_dashboard_url' do
    it 'returns admin URL' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect(decorated_tenant.admin_dashboard_url).to eq('https://test.example.com/admin')
    end

    it 'returns localhost admin URL in development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      expect(decorated_tenant.admin_dashboard_url).to eq('http://test.localhost:3000/admin')
    end
  end

  describe '#social_title' do
    it 'returns tenant title' do
      expect(decorated_tenant.social_title).to eq('Test Tenant')
    end
  end

  describe '#social_description' do
    it 'returns tenant description' do
      expect(decorated_tenant.social_description).to eq('Test description')
    end

    context 'when description is blank' do
      before { allow(tenant).to receive(:description).and_return('') }

      it 'returns default social description' do
        expect(decorated_tenant.social_description).to eq('Curated content from Test Tenant')
      end
    end
  end

  describe '#social_image_url' do
    context 'when tenant has logo' do
      before { tenant.update!(logo_url: 'https://example.com/logo.png') }

      it 'returns logo URL' do
        expect(decorated_tenant.social_image_url).to eq('https://example.com/logo.png')
      end
    end

    context 'when tenant has no logo' do
      before { allow(tenant).to receive(:logo_url).and_return(nil) }

      it 'returns default og-image URL' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        expect(decorated_tenant.social_image_url).to eq('https://test.example.com/og-image.png')
      end

      it 'returns localhost og-image URL in development' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        expect(decorated_tenant.social_image_url).to eq('http://test.localhost:3000/og-image.png')
      end
    end
  end

  describe '#twitter_handle' do
    it 'returns twitter handle based on slug' do
      expect(decorated_tenant.twitter_handle).to eq('@test')
    end
  end

  describe '#primary_color' do
    it 'returns theme primary color' do
      expect(decorated_tenant.primary_color).to eq('blue')
    end

    context 'when no theme settings' do
      before { tenant.update!(settings: {}) }

      it 'returns default color' do
        expect(decorated_tenant.primary_color).to eq('#3b82f6')
      end
    end
  end

  describe '#secondary_color' do
    it 'returns theme secondary color' do
      expect(decorated_tenant.secondary_color).to eq('gray')
    end

    context 'when no theme settings' do
      before { tenant.update!(settings: {}) }

      it 'returns default color' do
        expect(decorated_tenant.secondary_color).to eq('#6b7280')
      end
    end
  end

  describe '#logo_alt_text' do
    it 'returns proper alt text' do
      expect(decorated_tenant.logo_alt_text).to eq('Test Tenant logo')
    end
  end

  describe '#tenant_aria_label' do
    it 'returns proper aria label' do
      expect(decorated_tenant.tenant_aria_label).to eq('Tenant: Test Tenant')
    end
  end

  describe '#powered_by_curated?' do
    context 'for root tenant' do
      before { tenant.update!(slug: 'root') }

      it 'returns false' do
        expect(decorated_tenant.powered_by_curated?).to be false
      end
    end

    context 'for non-root tenant' do
      it 'returns true' do
        expect(decorated_tenant.powered_by_curated?).to be true
      end
    end
  end

  describe '#root_tenant?' do
    context 'when slug is root' do
      before { tenant.update!(slug: 'root') }

      it 'returns true' do
        expect(decorated_tenant.root_tenant?).to be true
      end
    end

    context 'when hostname is curated.cx' do
      before { tenant.update!(hostname: 'curated.cx') }

      it 'returns true' do
        expect(decorated_tenant.root_tenant?).to be true
      end
    end

    context 'for other tenants' do
      it 'returns false' do
        expect(decorated_tenant.root_tenant?).to be false
      end
    end
  end

  describe '#curated_main_url' do
    it 'returns development URL in development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      expect(decorated_tenant.curated_main_url).to eq('http://localhost:3000')
    end

    it 'returns production URL in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect(decorated_tenant.curated_main_url).to eq('https://curated.cx')
    end
  end

  describe '#powered_by_partial' do
    context 'for root tenant' do
      before { tenant.update!(slug: 'root') }

      it 'returns nil' do
        expect(decorated_tenant.powered_by_partial).to be_nil
      end
    end

    context 'for non-root tenant' do
      it 'returns powered by partial path' do
        partial = decorated_tenant.powered_by_partial
        expect(partial).to eq('shared/powered_by_footer')
      end
    end
  end

  describe '#absolute_url' do
    it 'returns base URL without path' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect(decorated_tenant.absolute_url).to eq('https://test.example.com')
    end

    it 'returns URL with path in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      expect(decorated_tenant.absolute_url('/admin')).to eq('https://test.example.com/admin')
    end

    it 'returns localhost subdomain URL in development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      expect(decorated_tenant.absolute_url).to eq('http://test.localhost:3000')
    end
  end

  describe '#tenant_directory_partial' do
    context 'for root tenant' do
      before { tenant.update!(slug: 'root') }

      context 'with enabled tenants' do
        let!(:other_tenant) { create(:tenant, title: 'Other Tenant', status: 'enabled') }

        it 'returns tenant directory partial path' do
          partial = decorated_tenant.tenant_directory_partial
          expect(partial).to eq('tenants/directory')
        end
      end

      context 'with no other enabled tenants' do
        it 'returns nil' do
          expect(decorated_tenant.tenant_directory_partial).to be_nil
        end
      end
    end

    context 'for non-root tenant' do
      it 'returns nil' do
        expect(decorated_tenant.tenant_directory_partial).to be_nil
      end
    end
  end
end
