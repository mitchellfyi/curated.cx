# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Robots", type: :request do
  let(:tenant) { create(:tenant, :enabled) }

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /robots.txt" do
    it "returns text content" do
      get robots_path(format: :txt)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/plain")
    end

    it "includes user-agent directive" do
      get robots_path(format: :txt)

      expect(response.body).to include("User-agent: *")
    end

    it "allows root" do
      get robots_path(format: :txt)

      expect(response.body).to include("Allow: /")
    end

    it "disallows admin" do
      get robots_path(format: :txt)

      expect(response.body).to include("Disallow: /admin/")
    end

    it "includes sitemap URL" do
      get robots_path(format: :txt)

      expect(response.body).to include("Sitemap:")
      expect(response.body).to include("/sitemap")
    end
  end
end
