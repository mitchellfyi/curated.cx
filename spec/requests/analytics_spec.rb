# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Analytics Integration", type: :request do
  let(:tenant) { create(:tenant, :enabled, slug: "test") }
  let(:site) { tenant.sites.first || create(:site, tenant: tenant) }

  before do
    Current.tenant = tenant
    Current.site = site
    host! "#{tenant.slug}.localhost"
  end

  describe "GA4 script inclusion" do
    context "when analytics is configured" do
      before do
        site.update!(config: { "analytics" => { "ga_measurement_id" => "G-TESTID123" } })
      end

      it "includes GA4 script tag" do
        get root_path

        expect(response.body).to include("googletagmanager.com/gtag/js?id=G-TESTID123")
      end

      it "includes consent mode setup" do
        get root_path

        expect(response.body).to include("gtag('consent', 'default'")
        expect(response.body).to include("analytics_storage")
      end

      it "includes anonymize_ip setting" do
        get root_path

        expect(response.body).to include("'anonymize_ip': true")
      end
    end

    context "when analytics is not configured" do
      it "does not include GA4 script" do
        get root_path

        expect(response.body).not_to include("googletagmanager.com/gtag/js")
      end
    end
  end

  describe "Cookie consent banner" do
    context "when analytics is configured" do
      before do
        site.update!(config: { "analytics" => { "ga_measurement_id" => "G-TESTID123" } })
      end

      it "includes cookie consent banner" do
        get root_path

        expect(response.body).to include('data-controller="cookie-consent"')
      end

      it "includes consent buttons" do
        get root_path

        expect(response.body).to include('data-action="click->cookie-consent#accept"')
        expect(response.body).to include('data-action="click->cookie-consent#reject"')
      end

      it "includes measurement ID in banner data" do
        get root_path

        expect(response.body).to include('data-cookie-consent-measurement-id-value="G-TESTID123"')
      end
    end

    context "when analytics is not configured" do
      it "does not include cookie consent banner" do
        get root_path

        expect(response.body).not_to include('data-controller="cookie-consent"')
      end
    end
  end
end
