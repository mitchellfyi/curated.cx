# Helper methods for internationalization testing
module I18nHelpers
  # Test with different locales
  def with_locale(locale, &block)
    original_locale = I18n.locale
    I18n.locale = locale
    yield
  ensure
    I18n.locale = original_locale
  end

  # Check if a translation key exists
  def translation_exists?(key, locale = I18n.locale)
    I18n.exists?(key, locale)
  end

  # Get all available locales for testing
  def available_locales
    I18n.available_locales
  end

  # Check for missing interpolation variables
  def check_interpolation(key, variables = {}, locale = I18n.locale)
    translation = I18n.t(key, **variables, locale: locale)
    
    # Check if translation contains untranslated interpolation variables
    untranslated_vars = translation.scan(/%\{([^}]+)\}/).flatten
    
    {
      translation: translation,
      missing_variables: untranslated_vars,
      has_missing_variables: untranslated_vars.any?
    }
  end

  # Test pluralization rules
  def test_pluralization(key, locale = I18n.locale)
    results = {}
    
    [0, 1, 2, 5].each do |count|
      results[count] = I18n.t(key, count: count, locale: locale)
    end
    
    results
  end

  # Generate test data with faker in different locales
  def localized_fake_data(locale = I18n.locale)
    with_locale(locale) do
      {
        name: Faker::Name.name,
        email: Faker::Internet.email,
        company: Faker::Company.name,
        address: Faker::Address.full_address,
        date: Faker::Date.forward(days: 30).strftime('%B %d, %Y')
      }
    end
  end
end

RSpec.configure do |config|
  config.include I18nHelpers
end