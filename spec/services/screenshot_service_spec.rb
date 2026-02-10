# frozen_string_literal: true

require "rails_helper"

RSpec.describe ScreenshotService do
  let(:url) { "https://example.com/article" }

  describe ".capture" do
    context "when API key is not configured" do
      before { allow(ENV).to receive(:fetch).and_call_original }

      it "raises ConfigurationError" do
        allow(ENV).to receive(:fetch).with("SCREENSHOT_API_KEY", nil).and_return(nil)

        expect { described_class.capture(url) }.to raise_error(
          ScreenshotService::ConfigurationError,
          "SCREENSHOT_API_KEY is not configured"
        )
      end
    end

    context "when API key is configured" do
      let(:api_key) { "test-api-key" }
      let(:api_url) { ScreenshotService::DEFAULT_API_URL }

      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("SCREENSHOT_API_KEY", nil).and_return(api_key)
        allow(ENV).to receive(:fetch).with("SCREENSHOT_API_URL", api_url).and_return(api_url)
      end

      context "when API returns JSON response" do
        let(:response_body) { { "screenshot" => "https://screenshots.example.com/abc123.png" }.to_json }

        before do
          stub_request(:get, /screenshotapi\.net/)
            .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })
        end

        it "returns screenshot URL and captured_at time" do
          result = described_class.capture(url)

          expect(result[:screenshot_url]).to eq("https://screenshots.example.com/abc123.png")
          expect(result[:captured_at]).to be_within(1.second).of(Time.current)
        end
      end

      context "when API returns non-JSON response without Location header" do
        before do
          stub_request(:get, /screenshotapi\.net/)
            .to_return(status: 200, body: "image data", headers: {
              "Content-Type" => "image/png"
            })
        end

        it "raises ScreenshotError" do
          expect { described_class.capture(url) }.to raise_error(
            ScreenshotService::ScreenshotError,
            /No screenshot URL in response/
          )
        end
      end

      context "when API returns non-JSON response with Location header" do
        before do
          stub_request(:get, /screenshotapi\.net/)
            .to_return(status: 200, body: "image data", headers: {
              "Content-Type" => "image/png",
              "Location" => "https://cdn.example.com/screenshot.png"
            })
        end

        it "returns the Location header URL" do
          result = described_class.capture(url)

          expect(result[:screenshot_url]).to eq("https://cdn.example.com/screenshot.png")
        end
      end

      context "when API returns client error" do
        before do
          stub_request(:get, /screenshotapi\.net/)
            .to_return(status: 400, body: "Bad Request")
        end

        it "raises ScreenshotError" do
          expect { described_class.capture(url) }.to raise_error(
            ScreenshotService::ScreenshotError,
            /API client error/
          )
        end
      end

      context "when API returns server error" do
        before do
          stub_request(:get, /screenshotapi\.net/)
            .to_return(status: 500, body: "Internal Server Error")
        end

        it "raises ScreenshotError" do
          expect { described_class.capture(url) }.to raise_error(
            ScreenshotService::ScreenshotError,
            /API server error/
          )
        end
      end

      context "when request times out" do
        before do
          stub_request(:get, /screenshotapi\.net/).to_timeout
        end

        it "raises ScreenshotError" do
          expect { described_class.capture(url) }.to raise_error(
            ScreenshotService::ScreenshotError
          )
        end
      end
    end
  end

  describe ".capture_for_entry" do
    let(:entry) { create(:entry, :feed) }

    before do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("SCREENSHOT_API_KEY", nil).and_return("test-key")
      allow(ENV).to receive(:fetch).with("SCREENSHOT_API_URL", anything).and_return(ScreenshotService::DEFAULT_API_URL)
    end

    context "when capture succeeds" do
      before do
        stub_request(:get, /screenshotapi\.net/)
          .to_return(status: 200, body: { "screenshot" => "https://screenshots.example.com/result.png" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "updates the content item with screenshot data" do
        described_class.capture_for_entry(entry)

        entry.reload
        expect(entry.screenshot_url).to eq("https://screenshots.example.com/result.png")
        expect(entry.screenshot_captured_at).to be_within(1.second).of(Time.current)
      end
    end

    context "when capture fails and OG image is available" do
      before do
        entry.update_columns(og_image_url: "https://example.com/og-image.jpg")
        stub_request(:get, /screenshotapi\.net/).to_timeout
      end

      it "falls back to OG image" do
        described_class.capture_for_entry(entry)

        entry.reload
        expect(entry.screenshot_url).to eq("https://example.com/og-image.jpg")
        expect(entry.screenshot_captured_at).to be_within(1.second).of(Time.current)
      end
    end

    context "when capture fails and no OG image is available" do
      before do
        stub_request(:get, /screenshotapi\.net/).to_timeout
      end

      it "returns nil and does not update content item" do
        result = described_class.capture_for_entry(entry)

        expect(result).to be_nil
        entry.reload
        expect(entry.screenshot_url).to be_nil
      end
    end
  end

  describe "constants" do
    it "has expected default values" do
      expect(ScreenshotService::DEFAULT_VIEWPORT_WIDTH).to eq(1280)
      expect(ScreenshotService::DEFAULT_VIEWPORT_HEIGHT).to eq(800)
      expect(ScreenshotService::THUMBNAIL_WIDTH).to eq(640)
      expect(ScreenshotService::TIMEOUT).to eq(30)
    end
  end
end
