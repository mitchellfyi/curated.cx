# frozen_string_literal: true

require "rails_helper"

RSpec.describe HttpClient do
  let(:test_job_class) do
    Class.new(ApplicationJob) do
      include HttpClient

      def fetch(url, timeout: nil)
        http_get(url, timeout: timeout)
      end

      def fetch_json(url)
        http_get_json(url)
      end
    end
  end

  let(:job) { test_job_class.new }

  describe "#http_get" do
    context "with successful response" do
      it "returns the response" do
        stub_request(:get, "https://example.com/test")
          .to_return(status: 200, body: "success")

        response = job.fetch("https://example.com/test")
        expect(response.body).to eq("success")
      end

      it "sets user-agent header" do
        stub_request(:get, "https://example.com/test")
          .with(headers: { "User-Agent" => HttpClient::DEFAULT_USER_AGENT })
          .to_return(status: 200, body: "")

        job.fetch("https://example.com/test")
        expect(WebMock).to have_requested(:get, "https://example.com/test")
          .with(headers: { "User-Agent" => HttpClient::DEFAULT_USER_AGENT })
      end
    end

    context "with client error" do
      it "raises HttpError with status code" do
        stub_request(:get, "https://example.com/404")
          .to_return(status: 404, body: "Not Found")

        expect { job.fetch("https://example.com/404") }
          .to raise_error(HttpClient::HttpError) { |error|
            expect(error.code).to eq(404)
          }
      end
    end

    context "with server error" do
      it "raises HttpError with status code" do
        stub_request(:get, "https://example.com/500")
          .to_return(status: 500, body: "Server Error")

        expect { job.fetch("https://example.com/500") }
          .to raise_error(HttpClient::HttpError) { |error|
            expect(error.code).to eq(500)
          }
      end
    end

    context "with timeout" do
      it "raises TimeoutError" do
        stub_request(:get, "https://example.com/timeout")
          .to_timeout

        expect { job.fetch("https://example.com/timeout") }
          .to raise_error(HttpClient::TimeoutError)
      end
    end

    context "with connection failure" do
      it "raises ConnectionError" do
        stub_request(:get, "https://example.com/fail")
          .to_raise(SocketError.new("Failed to open TCP connection"))

        expect { job.fetch("https://example.com/fail") }
          .to raise_error(HttpClient::ConnectionError)
      end
    end
  end

  describe "#http_get_json" do
    it "parses JSON response" do
      stub_request(:get, "https://example.com/json")
        .to_return(status: 200, body: '{"key": "value"}')

      result = job.fetch_json("https://example.com/json")
      expect(result).to eq({ "key" => "value" })
    end

    it "raises HttpError for invalid JSON" do
      stub_request(:get, "https://example.com/invalid")
        .to_return(status: 200, body: "not json")

      expect { job.fetch_json("https://example.com/invalid") }
        .to raise_error(HttpClient::HttpError, /Invalid JSON/)
    end
  end
end
