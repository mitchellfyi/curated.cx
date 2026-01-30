# frozen_string_literal: true

# Helper methods for Google Analytics 4 integration.
# Provides gtag event tracking and script tag generation.
module AnalyticsHelper
  # Returns true if analytics tracking should be enabled.
  # Requires valid measurement ID and user consent.
  def analytics_enabled?
    Current.site&.analytics_enabled?
  end

  # Returns the GA4 measurement ID for the current site.
  def ga_measurement_id
    Current.site&.ga_measurement_id
  end

  # Generates a gtag event call with proper escaping.
  # @param event_name [String] The GA4 event name
  # @param params [Hash] Event parameters
  # @return [String] JavaScript gtag call
  def gtag_event(event_name, params = {})
    return "" unless analytics_enabled?

    escaped_params = params.to_json
    "gtag('event', '#{j(event_name)}', #{escaped_params});"
  end

  # Data attributes for analytics tracking via Stimulus controller.
  # @param event_name [String] The event to track
  # @param params [Hash] Additional event parameters
  # @return [Hash] Data attributes for an HTML element
  def analytics_data(event_name, params = {})
    {
      controller: "analytics",
      action: "click->analytics#track",
      analytics_event_value: event_name,
      analytics_params_value: params.to_json
    }
  end
end
