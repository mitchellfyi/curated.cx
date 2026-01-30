# frozen_string_literal: true

# Controller for token-based file downloads.
# No authentication required - access is controlled by the download token.
#
# Routes:
#   GET /downloads/:token - Download file or show error
#
class DownloadsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  skip_before_action :verify_authenticity_token, only: :show

  # GET /downloads/:token
  def show
    @download_token = DownloadToken.find_by(token: params[:token])

    unless @download_token
      return render :not_found, status: :not_found
    end

    if @download_token.expired?
      return render :expired, status: :gone
    end

    if @download_token.exhausted?
      return render :exhausted, status: :gone
    end

    digital_product = @download_token.digital_product

    unless digital_product.file.attached?
      return render :file_unavailable, status: :not_found
    end

    # Record the download
    @download_token.record_download!
    digital_product.increment_download_count!

    # Log IP hash for abuse detection
    ip_hash = Digest::SHA256.hexdigest(request.remote_ip.to_s)[0..15]
    Rails.logger.info("Download recorded: token=#{@download_token.token[0..8]}..., ip_hash=#{ip_hash}")

    # Redirect to signed URL (1 hour expiry)
    redirect_to digital_product.file.url(expires_in: 1.hour), allow_other_host: true
  end
end
