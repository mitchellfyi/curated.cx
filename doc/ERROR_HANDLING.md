# Error Handling Patterns

This document describes the standardized error handling patterns used throughout the Curated.www application.

## Error Hierarchy

All application-specific errors inherit from `ApplicationError` in `app/errors/application_error.rb`:

```
StandardError
  └── ApplicationError          # Base for all app errors
        ├── ExternalServiceError   # Transient API/network failures (retryable)
        ├── ContentExtractionError # Parsing/scraping failures
        ├── ConfigurationError     # Permanent setup errors (discard job)
        └── DnsError               # DNS resolution failures (retryable)
```

### Error Types

| Error Class | Use Case | Retry? |
|-------------|----------|--------|
| `ExternalServiceError` | HTTP timeouts, API failures, network errors | Yes |
| `ContentExtractionError` | HTML parsing, metadata extraction failures | Depends |
| `ConfigurationError` | Missing API keys, invalid setup | No (discard) |
| `DnsError` | DNS resolution failures | Yes |

### Creating Errors with Context

All application errors support a `context` hash for structured logging:

```ruby
raise ExternalServiceError.new(
  "Failed to fetch data from API",
  context: { url: url, status: response.status }
)
```

Access the context via `error.context` or serialize with `error.to_h`.

## Job Error Handling

### Base Configuration (ApplicationJob)

`ApplicationJob` defines consistent error handling for all jobs:

```ruby
class ApplicationJob < ActiveJob::Base
  # Retry transient errors with exponential backoff
  retry_on ExternalServiceError, wait: :exponentially_longer, attempts: 3
  retry_on DnsError, wait: :exponentially_longer, attempts: 3

  # Discard permanent failures
  discard_on ConfigurationError
  discard_on ActiveRecord::RecordNotFound

  # Handle database deadlocks
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
end
```

### Structured Logging

Use the protected logging helpers from `ApplicationJob`:

```ruby
class MyJob < ApplicationJob
  def perform(record_id)
    # ... do work ...
  rescue SomeError => e
    log_job_error(e, record_id: record_id)
    raise
  end
end
```

**Available helpers:**

- `log_job_error(error, **context)` - Log errors with job/tenant context
- `log_job_warning(message, **context)` - Log warnings with context

These automatically include:
- `job_id` - The job's unique identifier
- `tenant_id` - Current tenant (if set)
- `site_id` - Current site (if set)
- `queue` - The queue name

### Job Error Handling Pattern

Follow this pattern for all jobs:

```ruby
class MyJob < ApplicationJob
  queue_as :default

  def perform(record_id)
    record = Record.find(record_id)

    # Set tenant context for multi-tenant operations
    Current.tenant = record.tenant
    Current.site = record.site

    # Do the work
    result = external_service_call(record)
    record.update!(result: result)

  rescue ExternalServiceError
    # Let retry_on handle this - just re-raise
    raise
  rescue StandardError => e
    # Log with context and re-raise for visibility
    log_job_error(e, record_id: record_id)
    raise
  ensure
    # Always clean up tenant context
    Current.tenant = nil
    Current.site = nil
  end

  private

  def external_service_call(record)
    # Wrap external calls to convert exceptions
    response = HTTPClient.get(record.url)
    # ... process response ...
  rescue Timeout::Error, Net::OpenTimeout => e
    raise ExternalServiceError.new(
      "Service timeout: #{e.message}",
      context: { url: record.url }
    )
  end
end
```

### Key Principles

1. **Wrap External Errors**: Convert library-specific exceptions to application errors
2. **Always Re-raise**: Never swallow errors silently - either handle them or re-raise
3. **Log Before Re-raise**: Use `log_job_error` to capture context
4. **Let `retry_on` Work**: Don't catch `ExternalServiceError` unless you have a reason
5. **Clean Up State**: Always reset `Current.*` in `ensure` blocks

## Service Error Handling

For services that may be called from jobs or controllers:

```ruby
class MyService
  def call(params)
    validate_configuration!
    perform_operation(params)
  rescue Net::OpenTimeout, Timeout::Error => e
    raise ExternalServiceError.new(
      "External service unavailable",
      context: { timeout: e.message }
    )
  end

  private

  def validate_configuration!
    raise ConfigurationError, "API_KEY not set" unless ENV["API_KEY"]
  end
end
```

## What NOT to Do

### Don't Use Bare Rescue

```ruby
# BAD - catches SystemExit, Interrupt, and other non-StandardError exceptions
begin
  risky_operation
rescue => e
  Rails.logger.error(e.message)
end

# GOOD - explicitly catch StandardError
begin
  risky_operation
rescue StandardError => e
  Rails.logger.error(e.message)
  raise # Re-raise unless you have a specific reason not to
end
```

### Don't Swallow Errors

```ruby
# BAD - silent failure, hides bugs
def fetch_data
  api.get_data
rescue StandardError
  nil # Error is silently ignored
end

# GOOD - log and re-raise, or handle specifically
def fetch_data
  api.get_data
rescue Timeout::Error => e
  log_job_error(e)
  raise ExternalServiceError.new("API timeout", context: { original: e.class.name })
end
```

### Don't Conflict with retry_on

```ruby
# BAD - catches the same error that retry_on is configured for
class MyJob < ApplicationJob
  retry_on StandardError, attempts: 3

  def perform
    do_work
  rescue StandardError
    nil # This prevents retry_on from working!
  end
end

# GOOD - let retry_on handle transient errors
class MyJob < ApplicationJob
  retry_on ExternalServiceError, attempts: 3

  def perform
    do_work
  rescue ExternalServiceError
    raise # Re-raise to let retry_on handle it
  rescue StandardError => e
    log_job_error(e)
    raise # Still re-raise for visibility
  end
end
```

## Testing Error Handling

Test that jobs handle errors correctly:

```ruby
RSpec.describe MyJob do
  describe "error handling" do
    it "retries on ExternalServiceError" do
      # Verify retry_on is configured
      expect(described_class.retry_on_errors).to include(ExternalServiceError)
    end

    it "discards on ConfigurationError" do
      expect(described_class.discard_on_errors).to include(ConfigurationError)
    end

    it "logs errors with context" do
      allow(Rails.logger).to receive(:error)

      expect {
        described_class.perform_now(invalid_id)
      }.to raise_error(StandardError)

      expect(Rails.logger).to have_received(:error).with(/MyJob failed/)
    end
  end
end
```

## Quick Reference

| Scenario | Action |
|----------|--------|
| Network timeout | Wrap in `ExternalServiceError`, let retry |
| Invalid HTML | Log warning, return nil (expected for bad content) |
| Missing API key | Raise `ConfigurationError` (permanent) |
| Record deleted | Let `discard_on RecordNotFound` handle it |
| Unknown error | Log with `log_job_error`, re-raise |
| DNS failure | Wrap in `DnsError`, let retry |
