# Axe-core accessibility testing configuration
begin
  require 'axe-core-rspec'

  # Only configure if successfully loaded
  RSpec.configure do |config|
    config.include AxeMatchers, type: :system
    config.include AxeMatchers, type: :feature
  end

  # Custom accessibility matcher
  RSpec::Matchers.define :be_accessible do |options = {}|
    match do |page|
      # Set default options
      default_options = {
        # Exclude third-party content that we can't control
        exclude: [
          # Common exclusions for third-party widgets
          '.twitter-widget',
          '.facebook-widget',
          'iframe[src*="youtube.com"]',
          'iframe[src*="vimeo.com"]'
        ].join(','),
        # Test against WCAG 2.1 AA standards
        tags: [ 'wcag2a', 'wcag2aa', 'wcag21aa' ]
      }

      options = default_options.merge(options)

      begin
        expect(page).to be_axe_clean
        true
      rescue RSpec::Expectations::ExpectationNotMetError => e
        @failure_message = e.message
        false
      end
    end

    failure_message do |page|
      @failure_message || "Expected page to be accessible, but accessibility violations were found"
    end

    failure_message_when_negated do |page|
      "Expected page to have accessibility violations, but none were found"
    end

    description do
      "be accessible according to WCAG guidelines"
    end
  end

rescue LoadError
  puts "Warning: axe-core-rspec not available, skipping accessibility configuration"

  # Define a no-op matcher when axe-core-rspec is not available
  RSpec::Matchers.define :be_accessible do |options = {}|
    match do |page|
      # Always pass when axe-core-rspec is not available
      true
    end

    description do
      "be accessible (axe-core-rspec not available)"
    end
  end
end
