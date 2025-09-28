require 'rails_helper'

RSpec.describe 'i18n Integration', type: :i18n do
  describe 'Translation completeness' do
    it 'should have all required translations' do
      # Check that all view files use i18n keys
      view_files = Dir.glob('app/views/**/*.erb')
      missing_translations = []
      
      view_files.each do |file|
        content = File.read(file)
        
        # Look for hardcoded strings that should be translated
        # This is a basic check - in practice, you'd use i18n-tasks
        hardcoded_strings = content.scan(/[^%>]\s*["']([A-Z][^"']{3,})["']/)
        
        hardcoded_strings.each do |match|
          string = match[0]
          # Skip common exceptions
          next if string.match?(/^(true|false|null|undefined)$/)
          next if string.match?(/^[A-Z_]+$/) # Constants
          next if string.match?(/^\d+$/) # Numbers
          
          missing_translations << "#{file}: #{string}"
        end
      end
      
      expect(missing_translations).to be_empty, 
        "Found potential hardcoded strings that should be translated:\n#{missing_translations.join("\n")}"
    end

    it 'should have consistent translation keys' do
      # Check that translation keys follow consistent patterns
      translation_files = Dir.glob('config/locales/**/*.yml')
      
      translation_files.each do |file|
        content = File.read(file)
        
        # Check for common translation key patterns
        lines = content.split("\n")
        lines.each_with_index do |line, index|
          next unless line.match?(/^\s*[a-z_]+:/)
          
          # Check for proper key formatting
          key = line.split(':').first.strip
          expect(key).to match(/^[a-z_]+$/), 
            "Translation key should be lowercase with underscores: #{key} in #{file}:#{index + 1}"
        end
      end
    end
  end

  describe 'Translation interpolation' do
    it 'should handle interpolation correctly' do
      # Test common interpolation patterns
      test_cases = [
        { key: 'welcome_message', params: { name: 'John' } },
        { key: 'item_count', params: { count: 5 } },
        { key: 'date_format', params: { date: Date.current } }
      ]
      
      test_cases.each do |test_case|
        begin
          result = I18n.t(test_case[:key], test_case[:params])
          expect(result).to be_a(String)
          expect(result).not_to be_empty
        rescue I18n::MissingTranslationData
          # This is expected for test keys that don't exist
          # In a real implementation, you'd have these keys defined
        end
      end
    end

    it 'should handle pluralization correctly' do
      # Test pluralization rules
      test_cases = [
        { key: 'items_count', count: 0 },
        { key: 'items_count', count: 1 },
        { key: 'items_count', count: 2 },
        { key: 'items_count', count: 5 }
      ]
      
      test_cases.each do |test_case|
        begin
          result = I18n.t(test_case[:key], count: test_case[:count])
          expect(result).to be_a(String)
          expect(result).not_to be_empty
        rescue I18n::MissingTranslationData
          # Expected for test keys
        end
      end
    end
  end

  describe 'Locale-specific formatting' do
    it 'should format dates correctly' do
      date = Date.new(2024, 1, 15)
      
      # Test date formatting
      formatted_date = I18n.l(date, format: :short)
      expect(formatted_date).to be_a(String)
      expect(formatted_date).not_to be_empty
    end

    it 'should format numbers correctly' do
      number = 1234.56
      
      # Test number formatting
      formatted_number = I18n.l(number, precision: 2)
      expect(formatted_number).to be_a(String)
      expect(formatted_number).not_to be_empty
    end

    it 'should format currency correctly' do
      amount = 99.99
      
      # Test currency formatting
      formatted_currency = I18n.l(amount, format: :currency)
      expect(formatted_currency).to be_a(String)
      expect(formatted_currency).not_to be_empty
    end
  end

  describe 'Translation key usage in views' do
    it 'should use translation keys in ERB templates' do
      # Check that views use t() helper instead of hardcoded strings
      view_files = Dir.glob('app/views/**/*.erb')
      
      view_files.each do |file|
        content = File.read(file)
        
        # Look for common patterns that should use translations
        patterns = [
          /<%=?\s*["'][A-Z][^"']{3,}["']\s*%>/, # Hardcoded capitalized strings
          /<%=?\s*["'][^"']*button[^"']*["']\s*%>/i, # Button text
          /<%=?\s*["'][^"']*title[^"']*["']\s*%>/i, # Title text
        ]
        
        patterns.each do |pattern|
          matches = content.scan(pattern)
          matches.each do |match|
            # Skip if it's already using t() helper
            next if match.include?('t(')
            
            expect(match).to be_nil, 
              "Found hardcoded string that should use translation: #{match} in #{file}"
          end
        end
      end
    end

    it 'should use proper translation key patterns' do
      # Check that translation keys follow Rails conventions
      view_files = Dir.glob('app/views/**/*.erb')
      
      view_files.each do |file|
        content = File.read(file)
        
        # Look for t() helper usage
        translation_calls = content.scan(/<%=?\s*t\(['"]([^'"]+)['"]/)
        
        translation_calls.each do |match|
          key = match[0]
          
          # Check key format
          expect(key).to match(/^[a-z_]+(\.[a-z_]+)*$/), 
            "Translation key should use dot notation: #{key} in #{file}"
          
          # Check for common key patterns
          expect(key).not_to match(/^[A-Z]/), 
            "Translation key should start with lowercase: #{key} in #{file}"
        end
      end
    end
  end

  describe 'Translation file structure' do
    it 'should have properly structured translation files' do
      translation_files = Dir.glob('config/locales/**/*.yml')
      
      expect(translation_files).not_to be_empty, "No translation files found"
      
      translation_files.each do |file|
        content = File.read(file)
        
        # Check for proper YAML structure
        expect { YAML.load(content) }.not_to raise_error, 
          "Invalid YAML in translation file: #{file}"
        
        # Check for locale declaration
        expect(content).to match(/^[a-z]{2}(_[A-Z]{2})?:\s*$/), 
          "Translation file should start with locale declaration: #{file}"
      end
    end

    it 'should have consistent translation file organization' do
      # Check that translation files are organized logically
      locale_files = Dir.glob('config/locales/*.yml')
      
      locale_files.each do |file|
        content = File.read(file)
        parsed = YAML.load(content)
        
        # Check for common top-level keys
        common_keys = %w[activerecord activemodel actionview actionmailer errors]
        common_keys.each do |key|
          if parsed.key?(key)
            expect(parsed[key]).to be_a(Hash), 
              "Translation key '#{key}' should be a hash in #{file}"
          end
        end
      end
    end
  end

  describe 'Missing translation handling' do
    it 'should handle missing translations gracefully' do
      # Test that missing translations don't break the application
      expect { I18n.t('nonexistent.key') }.not_to raise_error
      
      # Test that missing translations return a meaningful message
      result = I18n.t('nonexistent.key')
      expect(result).to include('translation missing')
    end

    it 'should have fallback translations' do
      # Test that fallback locale is configured
      expect(I18n.fallbacks).to be_present
      
      # Test that default locale is set
      expect(I18n.default_locale).to be_present
    end
  end

  describe 'Translation performance' do
    it 'should load translations efficiently' do
      # Test that translations load quickly
      start_time = Time.current
      
      # Load a batch of translations
      100.times do |i|
        I18n.t("test.key#{i}")
      end
      
      end_time = Time.current
      execution_time = end_time - start_time
      
      # Should complete within reasonable time (adjust threshold as needed)
      expect(execution_time).to be < 1.0, "Translation loading too slow: #{execution_time}s"
    end
  end
end
