# Axe-core accessibility testing configuration
begin
  require 'axe-rspec'

  RSpec.configure do |config|
    config.include AxeRspec::API, type: :system
    config.include AxeRspec::API, type: :feature
  end
rescue LoadError, NameError => e
  # Skip accessibility testing if axe-rspec is not available
  puts "Warning: axe-rspec not available, skipping accessibility configuration: #{e.message}"
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
      page.should be_axe_clean.according_to(*options[:tags]).excluding(options[:exclude])
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
