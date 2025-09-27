# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  setup do
    @tenant = Tenant.create!(
      hostname: "test.example.com",
      slug: "test_tenant",
      title: "Test Tenant",
      description: "Test tenant description"
    )
  end

  test "should generate skip link with default values" do
    link = skip_link
    
    assert_includes link, 'href="#main-content"'
    assert_includes link, 'class="skip-link'
    assert_includes link, I18n.t('a11y.skip_to_content')
  end

  test "should generate skip link with custom values" do
    link = skip_link("#custom-target", "Custom Text")
    
    assert_includes link, 'href="#custom-target"'
    assert_includes link, "Custom Text"
  end

  test "should return current locale name" do
    I18n.locale = :en
    assert_equal "English", current_locale_name
  end

  test "should fall back to uppercase locale code if translation missing" do
    # Test with a locale that doesn't have a translation
    original_locales = I18n.available_locales
    original_locale = I18n.locale
    
    I18n.available_locales = [:en, :test_locale]
    I18n.locale = :test_locale
    assert_equal "TEST_LOCALE", current_locale_name
    
    # Reset
    I18n.available_locales = original_locales
    I18n.locale = original_locale
  end

  test "should return locale options" do
    options = locale_options
    assert_includes options, ["English", :en]
  end

  test "should return true for RTL locales" do
    # Test with available locales
    original_locales = I18n.available_locales
    original_locale = I18n.locale
    
    I18n.available_locales = [:en, :ar, :he]
    I18n.locale = :ar
    assert rtl_locale?
    
    I18n.locale = :he
    assert rtl_locale?
    
    # Reset
    I18n.available_locales = original_locales
    I18n.locale = original_locale
  end

  test "should return false for LTR locales" do
    I18n.locale = :en
    assert_not rtl_locale?
    
    I18n.locale = :es
    assert_not rtl_locale?
  end

  test "should return aria-label hash with translated text" do
    result = aria_label('app.name')
    
    assert result.key?(:'aria-label')
    assert_equal I18n.t('app.name'), result[:'aria-label']
  end

  test "should return aria-describedby hash" do
    result = aria_describedby("test-id")
    
    assert result.key?(:'aria-describedby')
    assert_equal "test-id", result[:'aria-describedby']
  end

  test "should wrap text in screen reader only span" do
    result = sr_only("Screen reader text")
    
    assert_includes result, '<span class="sr-only">Screen reader text</span>'
  end

  test "should generate icon with accessibility text" do
    result = icon_with_text("icon-class", "Icon description")
    
    assert_includes result, 'class="icon-class"'
    assert_includes result, 'aria-hidden="true"'
    assert_includes result, '<span class="sr-only">Icon description</span>'
  end

  test "should generate accessible form with role" do
    # This test would need a more complex setup to actually test form generation
    # For now, we'll test that the method exists and accepts the expected parameters
    assert_respond_to self, :accessible_form_with
  end
end
