# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV.fetch("SENTRY_DSN", "https://b9d1397c94515abbd33442a539ed2d9a@o4509412457906176.ingest.de.sentry.io/4510822660112464")
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.traces_sample_rate = 1.0

  # Send request headers and IP for users (see Sentry data management docs)
  config.send_default_pii = true
end
