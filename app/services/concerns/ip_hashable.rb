# frozen_string_literal: true

# Provides consistent IP address hashing for privacy-preserving tracking.
# Uses SHA256 with application secret as salt.
#
# Usage:
#   class MyService
#     class << self
#       include IpHashable
#     end
#   end
module IpHashable
  def hash_ip(ip)
    return nil if ip.blank?

    Digest::SHA256.hexdigest("#{ip}:#{Rails.application.secret_key_base}")
  end
end
