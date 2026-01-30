# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnalyticsHelper, type: :helper do
  let(:tenant) { create(:tenant, :enabled) }
  let(:site) { create(:site, tenant: tenant) }

  before do
    Current.tenant = tenant
    Current.site = site
  end

  describe "#analytics_enabled?" do
    context "when site has GA measurement ID configured" do
      before do
        site.update!(config: { "analytics" => { "ga_measurement_id" => "G-TESTID123" } })
      end

      it "returns true" do
        expect(helper.analytics_enabled?).to be true
      end
    end

    context "when site has no GA measurement ID" do
      it "returns false" do
        expect(helper.analytics_enabled?).to be false
      end
    end

    context "when no current site" do
      before { Current.site = nil }

      it "returns falsey" do
        expect(helper.analytics_enabled?).to be_falsey
      end
    end
  end

  describe "#ga_measurement_id" do
    context "when configured" do
      before do
        site.update!(config: { "analytics" => { "ga_measurement_id" => "G-TESTID123" } })
      end

      it "returns the measurement ID" do
        expect(helper.ga_measurement_id).to eq("G-TESTID123")
      end
    end

    context "when not configured" do
      it "returns nil" do
        expect(helper.ga_measurement_id).to be_nil
      end
    end
  end

  describe "#gtag_event" do
    context "when analytics is enabled" do
      before do
        site.update!(config: { "analytics" => { "ga_measurement_id" => "G-TESTID123" } })
      end

      it "generates a gtag event call" do
        result = helper.gtag_event("button_click", { button_name: "signup" })
        expect(result).to include("gtag('event', 'button_click'")
        expect(result).to include('"button_name":"signup"')
      end

      it "escapes event names properly" do
        result = helper.gtag_event("test'event", {})
        expect(result).to include("gtag('event', 'test\\'event'")
      end
    end

    context "when analytics is disabled" do
      it "returns empty string" do
        result = helper.gtag_event("button_click", {})
        expect(result).to eq("")
      end
    end
  end

  describe "#analytics_data" do
    it "returns data attributes for tracking" do
      result = helper.analytics_data("form_submit", { form_type: "contact" })

      expect(result[:controller]).to eq("analytics")
      expect(result[:action]).to eq("click->analytics#track")
      expect(result[:analytics_event_value]).to eq("form_submit")
      expect(result[:analytics_params_value]).to include("form_type")
    end
  end
end
