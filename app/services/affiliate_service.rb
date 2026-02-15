# frozen_string_literal: true

# Service to detect affiliate-eligible URLs and determine the appropriate
# affiliate network for monetisation.
#
# Supported networks:
#   - Amazon Associates (amazon.com, amazon.co.uk, etc.)
#   - Impact/ShareASale (known SaaS merchants)
#   - CJ Affiliate (various brands)
#   - Awin (European brands)
#   - PartnerStack (B2B SaaS)
#
class AffiliateService
  AMAZON_DOMAINS = %w[
    amazon.com amazon.co.uk amazon.de amazon.fr amazon.it amazon.es
    amazon.ca amazon.com.au amazon.co.jp amazon.in amazon.com.br
    amazon.nl amazon.sg amazon.ae amazon.sa
  ].freeze

  # Map of known merchant domains to affiliate networks
  NETWORK_MERCHANTS = {
    "impact" => %w[
      notion.so canva.com grammarly.com semrush.com hubspot.com
      squarespace.com shopify.com wix.com hostinger.com bluehost.com
    ],
    "shareasale" => %w[
      tailwindcss.com weebly.com reebok.com warbyparker.com
    ],
    "cj" => %w[
      godaddy.com overstock.com lowes.com priceline.com
    ],
    "awin" => %w[
      etsy.com asos.com hp.com samsung.com
    ],
    "partnerstack" => %w[
      intercom.com gorgias.com pipedrive.com freshworks.com
    ]
  }.freeze

  class << self
    # Check if a URL is eligible for affiliate linking
    def eligible?(url)
      return false if url.blank?

      detect_network(url).present?
    end

    # Detect which affiliate network a URL belongs to
    def detect_network(url)
      return nil if url.blank?

      domain = extract_domain(url)
      return nil if domain.blank?

      return "amazon" if amazon_domain?(domain)

      NETWORK_MERCHANTS.each do |network, merchants|
        return network if merchants.any? { |m| domain_matches?(domain, m) }
      end

      nil
    end

    # Process a URL: detect network and return affiliate info
    def process_url(url)
      network = detect_network(url)
      return nil unless network

      {
        network: network,
        eligible: true,
        original_url: url
      }
    end

    # Scan an entry and update its affiliate fields
    # Uses update_columns to bypass callbacks/validations since we're only
    # updating derived metadata fields that don't require validation
    def scan_entry(entry)
      return unless entry.url_canonical.present?

      network = detect_network(entry.url_canonical)
      entry.update_columns(
        affiliate_eligible: network.present?,
        affiliate_network: network
      )
    end

    private

    def extract_domain(url)
      uri = URI.parse(url)
      uri.host&.downcase&.sub(/\Awww\./, "")
    rescue URI::InvalidURIError
      nil
    end

    def amazon_domain?(domain)
      AMAZON_DOMAINS.any? { |d| domain_matches?(domain, d) }
    end

    def domain_matches?(domain, target)
      domain == target || domain.end_with?(".#{target}")
    end
  end
end
