# frozen_string_literal: true

# Shared HTTP client utilities for background jobs
module HttpClient
  extend ActiveSupport::Concern

  DEFAULT_OPEN_TIMEOUT = 10
  DEFAULT_READ_TIMEOUT = 30
  DEFAULT_USER_AGENT = "Mozilla/5.0 (compatible; Curated.cx Fetcher/1.0)"

  class HttpError < StandardError
    attr_reader :code, :response

    def initialize(message, code: nil, response: nil)
      super(message)
      @code = code
      @response = response
    end
  end

  class TimeoutError < HttpError; end
  class ConnectionError < HttpError; end

  private

  def http_get(url, headers: {}, timeout: nil)
    uri = URI.parse(url)
    http = build_http_client(uri, timeout)

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = headers.delete("User-Agent") || DEFAULT_USER_AGENT
    headers.each { |k, v| request[k] = v }

    response = http.request(request)
    validate_response!(response)
    response
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise TimeoutError.new("Request timed out: #{e.message}")
  rescue SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET => e
    raise ConnectionError.new("Connection failed: #{e.message}")
  end

  def http_get_json(url, headers: {}, timeout: nil)
    response = http_get(url, headers: headers, timeout: timeout)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise HttpError.new("Invalid JSON response: #{e.message}")
  end

  def build_http_client(uri, timeout = nil)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = timeout || DEFAULT_OPEN_TIMEOUT
    http.read_timeout = timeout || DEFAULT_READ_TIMEOUT
    http
  end

  def validate_response!(response)
    return if response.is_a?(Net::HTTPSuccess)

    case response
    when Net::HTTPClientError
      raise HttpError.new("Client error: #{response.code} #{response.message}", code: response.code.to_i, response: response)
    when Net::HTTPServerError
      raise HttpError.new("Server error: #{response.code} #{response.message}", code: response.code.to_i, response: response)
    else
      raise HttpError.new("HTTP error: #{response.code} #{response.message}", code: response.code.to_i, response: response)
    end
  end
end
