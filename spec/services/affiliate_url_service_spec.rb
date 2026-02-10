# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AffiliateUrlService, type: :service do
  let(:tenant) { create(:tenant) }
  let(:category) { create(:category, tenant: tenant) }

  describe '#generate_url' do
    context 'with no affiliate template' do
      let(:entry) { build(:entry, :directory, tenant: tenant, category: category, affiliate_url_template: nil) }
      let(:service) { described_class.new(entry) }

      it 'returns nil' do
        expect(service.generate_url).to be_nil
      end
    end

    context 'with blank affiliate template' do
      let(:entry) { build(:entry, :directory, tenant: tenant, category: category, affiliate_url_template: '') }
      let(:service) { described_class.new(entry) }

      it 'returns nil' do
        expect(service.generate_url).to be_nil
      end
    end

    context 'with URL placeholder' do
      let(:entry) do
        create(:entry, :directory,
               tenant: tenant,
               category: category,
               url_raw: 'https://example.com/product',
               affiliate_url_template: 'https://affiliate.example.com?url={url}&ref=curated')
      end
      let(:service) { described_class.new(entry) }

      it 'replaces {url} with encoded canonical URL' do
        result = service.generate_url
        expect(result).to include('url=https%3A%2F%2Fexample.com%2Fproduct')
      end

      it 'keeps static query params' do
        result = service.generate_url
        expect(result).to include('ref=curated')
      end
    end

    context 'with title placeholder' do
      let(:entry) do
        create(:entry, :directory,
               tenant: tenant,
               category: category,
               title: 'My Product Name',
               affiliate_url_template: 'https://affiliate.example.com?title={title}')
      end
      let(:service) { described_class.new(entry) }

      it 'replaces {title} with encoded title' do
        result = service.generate_url
        expect(result).to include('title=My+Product+Name')
      end
    end

    context 'with ID placeholder' do
      let(:entry) do
        create(:entry, :directory,
               tenant: tenant,
               category: category,
               affiliate_url_template: 'https://affiliate.example.com?entry_id={id}')
      end
      let(:service) { described_class.new(entry) }

      it 'replaces {id} with entry ID' do
        result = service.generate_url
        expect(result).to include("entry_id=#{entry.id}")
      end
    end

    context 'with multiple placeholders' do
      let(:entry) do
        create(:entry, :directory,
               tenant: tenant,
               category: category,
               url_raw: 'https://example.com',
               title: 'Product',
               affiliate_url_template: 'https://affiliate.example.com?url={url}&title={title}&id={id}')
      end
      let(:service) { described_class.new(entry) }

      it 'replaces all placeholders' do
        result = service.generate_url
        expect(result).to include('url=')
        expect(result).to include('title=Product')
        expect(result).to include("id=#{entry.id}")
      end
    end

    context 'with affiliate attribution' do
      let(:entry) do
        create(:entry, :directory,
               tenant: tenant,
               category: category,
               affiliate_url_template: 'https://affiliate.example.com?url={url}',
               affiliate_attribution: { source: 'curated', campaign: 'tools' })
      end
      let(:service) { described_class.new(entry) }

      it 'appends attribution params to URL' do
        result = service.generate_url
        expect(result).to include('source=curated')
        expect(result).to include('campaign=tools')
      end
    end

    context 'with empty affiliate attribution' do
      let(:entry) do
        create(:entry, :directory,
               tenant: tenant,
               category: category,
               affiliate_url_template: 'https://affiliate.example.com?url={url}',
               affiliate_attribution: {})
      end
      let(:service) { described_class.new(entry) }

      it 'returns URL without extra params' do
        result = service.generate_url
        expect(result).to eq("https://affiliate.example.com?url=#{CGI.escape(entry.url_canonical)}")
      end
    end

    context 'with invalid URL template' do
      let(:entry) do
        build(:entry, :directory,
              tenant: tenant,
              category: category,
              affiliate_url_template: 'not-a-valid-url')
      end
      let(:service) { described_class.new(entry) }

      it 'returns the template with placeholders replaced' do
        expect(service.generate_url).to eq('not-a-valid-url')
      end
    end
  end

  describe '#track_click' do
    let(:entry) do
      create(:entry, :directory, :with_affiliate, tenant: tenant, category: category)
    end
    let(:service) { described_class.new(entry) }
    let(:request) do
      instance_double(
        ActionDispatch::Request,
        remote_ip: '192.168.1.1',
        user_agent: 'Mozilla/5.0 Test Browser',
        referrer: 'https://google.com/search?q=test'
      )
    end

    it 'creates an AffiliateClick record' do
      expect { service.track_click(request) }.to change(AffiliateClick, :count).by(1)
    end

    it 'sets the entry association' do
      click = service.track_click(request)
      expect(click.entry).to eq(entry)
    end

    it 'sets clicked_at to current time' do
      freeze_time do
        click = service.track_click(request)
        expect(click.clicked_at).to eq(Time.current)
      end
    end

    it 'hashes the IP address for privacy' do
      click = service.track_click(request)
      expect(click.ip_hash).not_to eq('192.168.1.1')
      expect(click.ip_hash).to be_present
      expect(click.ip_hash.length).to eq(16)
    end

    it 'stores the user agent (truncated)' do
      click = service.track_click(request)
      expect(click.user_agent).to eq('Mozilla/5.0 Test Browser')
    end

    it 'stores the referrer (truncated)' do
      click = service.track_click(request)
      expect(click.referrer).to eq('https://google.com/search?q=test')
    end

    context 'with nil IP' do
      let(:request) do
        instance_double(
          ActionDispatch::Request,
          remote_ip: nil,
          user_agent: 'Test',
          referrer: nil
        )
      end

      it 'sets ip_hash to nil' do
        click = service.track_click(request)
        expect(click.ip_hash).to be_nil
      end
    end

    context 'with long user agent' do
      let(:request) do
        instance_double(
          ActionDispatch::Request,
          remote_ip: '192.168.1.1',
          user_agent: 'A' * 500,
          referrer: nil
        )
      end

      it 'truncates user agent to 255 characters' do
        click = service.track_click(request)
        expect(click.user_agent.length).to eq(255)
      end
    end

    context 'with long referrer' do
      let(:request) do
        instance_double(
          ActionDispatch::Request,
          remote_ip: '192.168.1.1',
          user_agent: 'Test',
          referrer: 'https://example.com/' + 'a' * 3000
        )
      end

      it 'truncates referrer to 2000 characters' do
        click = service.track_click(request)
        expect(click.referrer.length).to eq(2000)
      end
    end

    context 'with unpersisted entry' do
      let(:entry) { build(:entry, :directory, tenant: tenant, category: category) }

      it 'returns nil without creating a click' do
        expect(service.track_click(request)).to be_nil
        expect(AffiliateClick.count).to eq(0)
      end
    end
  end

  describe '.generate_url_for' do
    let(:entry) do
      create(:entry, :directory,
             tenant: tenant,
             category: category,
             affiliate_url_template: 'https://affiliate.example.com?url={url}')
    end

    it 'creates a service and calls generate_url' do
      result = described_class.generate_url_for(entry)
      expect(result).to include('affiliate.example.com')
    end
  end

  describe '.track_click_for' do
    let(:entry) { create(:entry, :directory, :with_affiliate, tenant: tenant, category: category) }
    let(:request) do
      instance_double(
        ActionDispatch::Request,
        remote_ip: '192.168.1.1',
        user_agent: 'Test',
        referrer: nil
      )
    end

    it 'creates a service and calls track_click' do
      expect { described_class.track_click_for(entry, request) }
        .to change(AffiliateClick, :count).by(1)
    end
  end
end
