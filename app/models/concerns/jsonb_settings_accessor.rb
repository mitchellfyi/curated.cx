# frozen_string_literal: true

# Provides JSONB settings accessor methods with dot notation support
# for nested key access. Include this concern and configure the column name:
#
#   include JsonbSettingsAccessor
#   self.jsonb_settings_column = :config  # or :settings
#
# Then use:
#   setting("theme.primary_color", "blue")  # Get with default
#   update_setting("theme.primary_color", "red")  # Set and save
#
module JsonbSettingsAccessor
  extend ActiveSupport::Concern

  included do
    class_attribute :jsonb_settings_column, default: :settings
  end

  # Get a setting value using dot notation for nested keys
  # Returns the default if the key is missing or nil
  #
  # @param key [String, Symbol] Dot-notation key path (e.g., "theme.primary_color")
  # @param default [Object] Value to return if key is missing or nil
  # @return [Object] The setting value or default
  def setting(key, default = nil)
    keys = key.to_s.split(".")
    value = jsonb_settings_data
    keys.each do |k|
      value = value[k] if value.is_a?(Hash)
    end
    value.nil? ? default : value
  end

  # Update a setting value using dot notation for nested keys
  # Creates intermediate hash structures as needed
  # Persists the change to the database immediately
  #
  # @param key [String, Symbol] Dot-notation key path
  # @param value [Object] The value to set
  # @return [Boolean] Result of save!
  def update_setting(key, value)
    keys = key.to_s.split(".")
    new_data = jsonb_settings_data.deep_dup

    # Navigate to the nested location
    current = new_data
    keys[0..-2].each do |k|
      current[k] ||= {}
      current = current[k]
    end

    # Set the final value
    current[keys.last] = value

    write_attribute(jsonb_settings_column, new_data)
    save!
  end

  private

  # Read the JSONB column data, ensuring it returns an empty hash if nil
  def jsonb_settings_data
    read_attribute(jsonb_settings_column) || {}
  end
end
