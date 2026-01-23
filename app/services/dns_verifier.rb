# frozen_string_literal: true

require "resolv"

# Service to verify DNS configuration for custom domains.
# Checks A records for apex domains and CNAME records for subdomains.
#
# Usage:
#   verifier = DnsVerifier.new(hostname: "example.com", expected_target: "curated.cx")
#   result = verifier.verify
#   # => { verified: true, records: ["192.168.1.100"] }
#   # => { verified: false, error: "No A records found for example.com" }
#
class DnsVerifier
  class ResolutionError < StandardError; end

  DEFAULT_TIMEOUT = [ 2, 2, 2 ].freeze # 2 second timeout per attempt

  def self.verify(hostname:, expected_target: nil)
    new(hostname: hostname, expected_target: expected_target).verify
  end

  def initialize(hostname:, expected_target: nil)
    @hostname = hostname
    @expected_target = expected_target || default_target
  end

  # Returns a hash with verification result:
  #   { verified: true, records: [...] }
  #   { verified: false, error: "..." }
  def verify
    return { verified: false, error: "Hostname is required" } if @hostname.blank?

    if apex_domain?
      verify_apex_domain
    else
      verify_subdomain
    end
  rescue Resolv::ResolvError => e
    { verified: false, error: "DNS resolution error: #{e.message}" }
  rescue => e
    { verified: false, error: "Verification error: #{e.message}" }
  end

  # Public accessors for testing and inspection
  attr_reader :hostname, :expected_target

  # Check if hostname is an apex domain (e.g., "example.com" vs "www.example.com")
  def apex_domain?
    return false if @hostname.blank?

    parts = @hostname.split(".")
    parts.length == 2
  end

  private

  def verify_apex_domain
    a_records = resolver.getresources(@hostname, Resolv::DNS::Resource::IN::A)

    if a_records.empty?
      return { verified: false, error: "No A records found for #{@hostname}" }
    end

    if ip_address?(@expected_target)
      verify_apex_against_ip(a_records)
    else
      verify_apex_against_hostname(a_records)
    end
  end

  def verify_apex_against_ip(a_records)
    matching = a_records.any? { |record| record.address.to_s == @expected_target }
    if matching
      { verified: true, records: a_records.map(&:address).map(&:to_s) }
    else
      found_ips = a_records.map(&:address).map(&:to_s).join(", ")
      { verified: false, error: "A records point to #{found_ips}, expected #{@expected_target}" }
    end
  end

  def verify_apex_against_hostname(a_records)
    target_ip = resolver.getaddress(@expected_target).to_s
    matching = a_records.any? { |record| record.address.to_s == target_ip }
    if matching
      { verified: true, records: a_records.map(&:address).map(&:to_s) }
    else
      found_ips = a_records.map(&:address).map(&:to_s).join(", ")
      { verified: false, error: "A records point to #{found_ips}, expected #{target_ip} (#{@expected_target})" }
    end
  end

  def verify_subdomain
    cname_records = resolver.getresources(@hostname, Resolv::DNS::Resource::IN::CNAME)

    if cname_records.empty?
      return { verified: false, error: "No CNAME record found for #{@hostname}" }
    end

    cname_target = cname_records.first.name.to_s.downcase
    expected_target_normalized = @expected_target.downcase

    if cname_target == expected_target_normalized || cname_target.end_with?(".#{expected_target_normalized}")
      { verified: true, records: [ cname_target ] }
    else
      { verified: false, error: "CNAME points to #{cname_target}, expected #{@expected_target}" }
    end
  end

  def ip_address?(string)
    /\A(\d{1,3}\.){3}\d{1,3}\z/.match?(string)
  end

  def default_target
    ENV.fetch("DNS_TARGET", "curated.cx")
  end

  def resolver
    @resolver ||= begin
      r = Resolv::DNS.new
      r.timeouts = DEFAULT_TIMEOUT
      r
    end
  end
end
