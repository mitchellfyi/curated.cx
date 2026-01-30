# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Downloads", type: :request do
  let(:tenant) { create(:tenant, :enabled) }

  def site
    Current.site
  end

  before do
    host! tenant.hostname
    setup_tenant_context(tenant)
  end

  describe "GET /downloads/:token" do
    context "with valid token and attached file" do
      let!(:product) { create(:digital_product, :published, :with_file, site: site) }
      let!(:purchase) { create(:purchase, digital_product: product) }
      let!(:download_token) { create(:download_token, :fresh, purchase: purchase) }

      before do
        # Stub ActiveStorage blob URL generation for request specs
        allow_any_instance_of(ActiveStorage::Blob).to receive(:url).and_return("https://example.com/file.pdf")
      end

      it "redirects to the file URL" do
        get download_path(download_token.token)
        expect(response).to have_http_status(:redirect)
        expect(response.location).to eq("https://example.com/file.pdf")
      end

      it "increments download count on token" do
        expect {
          get download_path(download_token.token)
        }.to change { download_token.reload.download_count }.by(1)
      end

      it "increments download count on product" do
        expect {
          get download_path(download_token.token)
        }.to change { product.reload.download_count }.by(1)
      end

      it "sets last_downloaded_at on token" do
        freeze_time do
          get download_path(download_token.token)
          expect(download_token.reload.last_downloaded_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    context "with expired token" do
      let!(:product) { create(:digital_product, :published, :with_file, site: site) }
      let!(:purchase) { create(:purchase, digital_product: product) }
      let!(:download_token) { create(:download_token, :expired, purchase: purchase) }

      it "returns 410 Gone" do
        get download_path(download_token.token)
        expect(response).to have_http_status(:gone)
      end

      it "renders expired template" do
        get download_path(download_token.token)
        expect(response).to render_template(:expired)
      end

      it "does not increment download count" do
        expect {
          get download_path(download_token.token)
        }.not_to change { download_token.reload.download_count }
      end
    end

    context "with exhausted token" do
      let!(:product) { create(:digital_product, :published, :with_file, site: site) }
      let!(:purchase) { create(:purchase, digital_product: product) }
      let!(:download_token) { create(:download_token, :exhausted, purchase: purchase, expires_at: 1.hour.from_now) }

      it "returns 410 Gone" do
        get download_path(download_token.token)
        expect(response).to have_http_status(:gone)
      end

      it "renders exhausted template" do
        get download_path(download_token.token)
        expect(response).to render_template(:exhausted)
      end
    end

    context "with non-existent token" do
      it "returns 404 Not Found" do
        get download_path("nonexistent-token-12345")
        expect(response).to have_http_status(:not_found)
      end

      it "renders not_found template" do
        get download_path("nonexistent-token-12345")
        expect(response).to render_template(:not_found)
      end
    end

    context "when file is not attached" do
      let!(:product) { create(:digital_product, :published, site: site) } # No file
      let!(:purchase) { create(:purchase, digital_product: product) }
      let!(:download_token) { create(:download_token, :fresh, purchase: purchase) }

      it "returns 404 Not Found" do
        get download_path(download_token.token)
        expect(response).to have_http_status(:not_found)
      end

      it "renders file_unavailable template" do
        get download_path(download_token.token)
        expect(response).to render_template(:file_unavailable)
      end
    end
  end
end
