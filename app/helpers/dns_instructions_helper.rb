# frozen_string_literal: true

module DnsInstructionsHelper
  # Get the VPS IP or canonical hostname for DNS records
  def dns_target
    ENV.fetch("DNS_TARGET", "curated.cx") # Default to curated.cx, can be overridden with VPS IP
  end

  # Determine if hostname is an apex domain
  def apex_domain?(hostname)
    return false if hostname.blank?
    parts = hostname.split(".")
    parts.length == 2 # e.g., "example.com" has 2 parts
  end

  # Determine if hostname is a subdomain
  def subdomain?(hostname)
    return false if hostname.blank?
    parts = hostname.split(".")
    parts.length >= 3 # e.g., "news.example.com" has 3 parts
  end

  # Get DNS instructions for a domain
  def dns_instructions_for(domain)
    hostname = domain.hostname
    is_apex = apex_domain?(hostname)
    target = dns_target

    if is_apex
      {
        type: "apex",
        hostname: hostname,
        records: [
          {
            type: "A",
            name: "@",
            value: target,
            note: "Point to VPS IP address"
          },
          {
            type: "ALIAS/ANAME",
            name: "@",
            value: target,
            note: "If your DNS provider supports ALIAS/ANAME records (e.g., Cloudflare, DNSimple)"
          }
        ],
        ttl: "3600 (1 hour) or your provider's default",
        notes: [
          "A records point directly to an IP address",
          "ALIAS/ANAME records point to a hostname (preferred if supported)",
          "Some providers require A records only"
        ]
      }
    else
      {
        type: "subdomain",
        hostname: hostname,
        records: [
          {
            type: "CNAME",
            name: hostname.split(".").first, # e.g., "news" from "news.example.com"
            value: target,
            note: "Point to canonical hostname"
          }
        ],
        ttl: "3600 (1 hour) or your provider's default",
        notes: [
          "CNAME records point to a hostname, not an IP address",
          "TTL of 3600 seconds (1 hour) is recommended for faster propagation",
          "Some DNS providers may require lower TTL for subdomains"
        ]
      }
    end
  end
end
