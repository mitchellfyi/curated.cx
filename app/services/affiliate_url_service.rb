# frozen_string_literal: true

# Service to generate affiliate URLs and track clicks for monetisation
#
# The affiliate_url_template supports placeholders:
#   {url} - The canonical URL of the listing (URL-encoded)
#   {title} - The listing title (URL-encoded)
#   {id} - The listing ID
#
# Example templates:
#   - "https://affiliate.example.com?url={url}&ref=curated"
#   - "https://example.com/go?target={url}&source=curated&campaign=tools"
#
class AffiliateUrlService
  attr_reader :listing

  def initialize(listing)
    @listing = listing
  end

  # Generate the affiliate URL from the template
  def generate_url
    return nil unless listing.affiliate_url_template.present?

    url = listing.affiliate_url_template.dup

    # Replace placeholders
    url = url.gsub("{url}", CGI.escape(listing.url_canonical.to_s))
    url = url.gsub("{title}", CGI.escape(listing.title.to_s))
    url = url.gsub("{id}", listing.id.to_s)

    # Apply attribution params if present
    apply_attribution_params(url)
  end

  # Track a click on the affiliate link
  def track_click(request)
    return nil unless listing.persisted?

    AffiliateClick.create!(
      listing: listing,
      clicked_at: Time.current,
      ip_hash: hash_ip(request.remote_ip),
      user_agent: truncate_user_agent(request.user_agent),
      referrer: truncate_referrer(request.referrer)
    )
  end

  # Class method for convenience
  def self.generate_url_for(listing)
    new(listing).generate_url
  end

  # Class method for tracking
  def self.track_click_for(listing, request)
    new(listing).track_click(request)
  end

  private

  # Apply additional attribution params from the JSONB field
  def apply_attribution_params(url)
    return url if listing.affiliate_attribution.blank?

    # Parse existing URL to add params
    uri = URI.parse(url)
    existing_params = uri.query ? URI.decode_www_form(uri.query) : []

    # Add attribution params
    listing.affiliate_attribution.each do |key, value|
      existing_params << [ key.to_s, value.to_s ]
    end

    uri.query = URI.encode_www_form(existing_params) if existing_params.any?
    uri.to_s
  rescue URI::InvalidURIError
    url # Return original if parsing fails
  end

  # Hash IP address for privacy (SHA256 truncated)
  def hash_ip(ip)
    return nil if ip.blank?

    Digest::SHA256.hexdigest("#{ip}#{Rails.application.secret_key_base}")[0..15]
  end

  # Truncate user agent to reasonable length
  def truncate_user_agent(user_agent)
    user_agent&.truncate(255)
  end

  # Truncate referrer to reasonable length
  def truncate_referrer(referrer)
    referrer&.truncate(2000)
  end
end
