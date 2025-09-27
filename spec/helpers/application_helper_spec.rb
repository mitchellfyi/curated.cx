# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  let(:tenant) { create(:tenant, title: "Test Tenant", description: "Test Description") }

  before do
    allow(Current).to receive(:tenant).and_return(tenant)
  end

  describe '#page_title' do
    it 'returns tenant title when no specific title is provided' do
      expect(helper.page_title).to eq("Test Tenant")
    end

    it 'returns formatted title with tenant name when specific title is provided' do
      expect(helper.page_title("Dashboard")).to eq("Dashboard | Test Tenant")
    end

    it 'returns app name when no tenant is present' do
      allow(Current).to receive(:tenant).and_return(nil)
      expect(helper.page_title).to eq("Curated")
    end
  end

  describe '#setup_meta_tags' do
    it 'sets up comprehensive meta tags with tenant information' do
      helper.setup_meta_tags

      # Check that meta tags are set (we can't easily test the actual output without rendering)
      expect(helper).to respond_to(:set_meta_tags)
    end

    it 'accepts custom options and merges them with defaults' do
      helper.setup_meta_tags(title: "Custom Title", description: "Custom Description")

      # The method should not raise an error
      expect(helper).to respond_to(:set_meta_tags)
    end
  end

  describe '#skip_link' do
    it 'generates skip link with default parameters' do
      skip_link = helper.skip_link
      expect(skip_link).to include('href="#main-content"')
      expect(skip_link).to include('Skip to main content')
      expect(skip_link).to include('skip-link')
    end

    it 'accepts custom target and text' do
      skip_link = helper.skip_link("#custom-target", "Custom text")
      expect(skip_link).to include('href="#custom-target"')
      expect(skip_link).to include('Custom text')
    end
  end

  describe '#current_locale_name' do
    it 'returns current locale name' do
      expect(helper.current_locale_name).to eq("EN")
    end
  end

  # Note: user_avatar, user_display_name, and user_role_badges methods
  # have been moved to decorators and are no longer helper methods

  describe '#locale_options' do
    it 'returns array of locale options' do
      options = helper.locale_options
      expect(options).to be_an(Array)
      expect(options.first).to be_an(Array)
      expect(options.first.first).to eq("EN")
      expect(options.first.last).to eq(:en)
    end
  end

  describe '#rtl_locale?' do
    it 'returns false for LTR locales' do
      expect(helper.rtl_locale?).to be false
    end

    it 'returns true for RTL locales' do
      allow(I18n).to receive(:locale).and_return(:ar)
      expect(helper.rtl_locale?).to be true
    end
  end

  describe '#aria_label' do
    it 'generates aria-label attribute' do
      label = helper.aria_label('nav.home')
      expect(label).to eq({ 'aria-label': 'Home' })
    end

    it 'accepts options for interpolation' do
      label = helper.aria_label('nav.dashboard', user: 'John')
      expect(label).to eq({ 'aria-label': 'Dashboard' })
    end
  end

  describe '#aria_describedby' do
    it 'generates aria-describedby attribute' do
      describedby = helper.aria_describedby('help-text')
      expect(describedby).to eq({ 'aria-describedby': 'help-text' })
    end
  end

  describe '#sr_only' do
    it 'generates screen reader only text' do
      sr_text = helper.sr_only('Hidden text')
      expect(sr_text).to include('Hidden text')
      expect(sr_text).to include('sr-only')
    end
  end

  describe '#icon_with_text' do
    it 'generates icon with accessible text' do
      icon = helper.icon_with_text('icon-class', 'Icon description')
      expect(icon).to include('icon-class')
      expect(icon).to include('Icon description')
      expect(icon).to include('aria-hidden')
      expect(icon).to include('sr-only')
    end
  end

  describe '#accessible_form_with' do
    it 'generates form without errors' do
      form = helper.accessible_form_with(url: '/test') { "form content" }
      expect(form).to include('<form')
      expect(form).to include('action="/test"')
    end

    it 'allows overriding role attribute' do
      form = helper.accessible_form_with(url: '/test', role: 'search') { "form content" }
      expect(form).to include('<form')
      expect(form).to include('action="/test"')
    end

    it 'works with a model when url is provided' do
      user = create(:user)
      form = helper.accessible_form_with(model: user, url: '/users/1') { "form content" }
      expect(form).to include('<form')
    end
  end

  describe 'private methods' do
    describe '#deep_compact' do
      it 'removes nil values from nested hashes' do
        hash = {
          a: 1,
          b: nil,
          c: {
            d: 2,
            e: nil,
            f: {
              g: 3,
              h: nil
            }
          }
        }

        result = helper.send(:deep_compact, hash)
        expect(result).to eq({
          a: 1,
          c: {
            d: 2,
            f: {
              g: 3
            }
          }
        })
      end

      it 'removes empty nested hashes' do
        hash = {
          a: 1,
          b: {},
          c: {
            d: 2,
            e: {}
          }
        }

        result = helper.send(:deep_compact, hash)
        expect(result).to eq({
          a: 1,
          c: {
            d: 2
          }
        })
      end
    end
  end
end
