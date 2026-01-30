# frozen_string_literal: true

# Mailer for digital product purchase receipts and download links.
class DigitalProductMailer < ApplicationMailer
  # Send a purchase receipt with download link to the customer.
  # @param purchase [Purchase] The purchase record
  def purchase_receipt(purchase)
    @purchase = purchase
    @digital_product = purchase.digital_product
    @download_token = purchase.download_tokens.order(created_at: :desc).first

    return unless @download_token.present?

    @download_url = download_url(@download_token.token)
    @expires_at = @download_token.expires_at
    @max_downloads = @download_token.max_downloads

    mail(
      to: purchase.email,
      subject: t("digital_product_mailer.purchase_receipt.subject", product_title: @digital_product.title)
    )
  end
end
