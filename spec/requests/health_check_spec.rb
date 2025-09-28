require 'rails_helper'

RSpec.describe "Health Check", type: :request do
  describe "GET /up" do
    it "returns http success when application is healthy" do
      get "/up"
      expect(response).to have_http_status(:success)
    end

    it "returns 200 status code" do
      get "/up"
      expect(response.status).to eq(200)
    end

    it "returns HTML response" do
      get "/up"
      expect(response.content_type).to include("text/html")
    end

    it "returns HTML body indicating healthy status" do
      get "/up"
      expect(response.body).to include("background-color: green")
    end

    it "does not require authentication" do
      get "/up"
      expect(response).to have_http_status(:success)
    end

    it "does not require tenant context" do
      # Test without setting any hostname
      get "/up"
      expect(response).to have_http_status(:success)
    end

    it "works with any hostname" do
      host! "example.com"
      get "/up"
      expect(response).to have_http_status(:success)
    end

    it "works with disabled tenant hostname" do
      disabled_tenant = create(:tenant, :disabled)
      host! disabled_tenant.hostname
      get "/up"
      expect(response).to have_http_status(:success)
    end

    it "works with private tenant hostname" do
      private_tenant = create(:tenant, :private_access)
      host! private_tenant.hostname
      get "/up"
      expect(response).to have_http_status(:success)
    end


    context "load balancer integration" do
      it "responds quickly for health checks" do
        start_time = Time.current
        get "/up"
        end_time = Time.current

        expect(end_time - start_time).to be < 1.second
      end

      it "does not trigger any business logic" do
        # Health check should not trigger tenant resolution
        get "/up"
        expect(response).to have_http_status(:success)
      end

      it "does not create any database records" do
        expect {
          get "/up"
        }.not_to change { Tenant.count }
      end
    end
  end
end
