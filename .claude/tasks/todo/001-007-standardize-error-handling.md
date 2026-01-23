# Task: Standardize Error Handling Patterns

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-007-standardize-error-handling` |
| Status | `todo` |
| Priority | `001` Critical |
| Created | `2026-01-23 01:00` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

---

## Context

Error handling is inconsistent across the codebase:

**Problem 1: Bare Rescues (8 instances)**
```ruby
# ScrapeMetadataJob
rescue StandardError
  nil  # Swallows ALL errors including programming bugs

# Domain model
rescue => e  # Catches SystemExit, Interrupt - dangerous!
```

**Problem 2: Inconsistent Job Error Strategy**
```ruby
# FetchRssJob: Re-raises after logging
rescue StandardError => e
  source.update_run_status("error: #{e.message}")
  raise  # Will retry

# ScrapeMetadataJob: Swallows errors
rescue StandardError => e
  Rails.logger.error(...)
  nil  # Won't retry, silent failure
```

**Problem 3: No Error Hierarchy**
- No custom exception classes
- Can't distinguish recoverable vs fatal errors
- No way to handle specific error types

---

## Acceptance Criteria

- [ ] Create `app/errors/` directory with error hierarchy
- [ ] Replace all bare `rescue` with specific exceptions
- [ ] Define consistent job error handling strategy
- [ ] Add error logging with context (request_id, tenant_id)
- [ ] Document error handling patterns in code or README
- [ ] All jobs follow same retry/fail pattern
- [ ] No `rescue => e` or `rescue StandardError` without re-raise
- [ ] Quality gates pass

---

## Plan

1. **Create Error Hierarchy**
   - File: `app/errors/application_error.rb`
   ```ruby
   class ApplicationError < StandardError; end
   class ExternalApiError < ApplicationError; end
   class ValidationError < ApplicationError; end
   class DnsVerificationError < ApplicationError; end
   class ContentExtractionError < ApplicationError; end
   ```

2. **Define Job Error Strategy**
   ```ruby
   # Standard pattern for all jobs:
   def perform(...)
     # ... work ...
   rescue ExternalApiError => e
     # Retry with backoff (transient)
     raise
   rescue ValidationError => e
     # Don't retry (permanent failure)
     Rails.logger.error(...)
   rescue StandardError => e
     # Unknown error - log and retry
     Rails.logger.error(...)
     raise
   end
   ```

3. **Fix Bare Rescues**
   - Audit each `rescue` statement
   - Replace with specific exception types
   - Ensure proper re-raising where needed

4. **Add Error Context**
   ```ruby
   Rails.logger.error({
     error: e.class.name,
     message: e.message,
     tenant_id: Current.tenant&.id,
     backtrace: e.backtrace.first(5)
   }.to_json)
   ```

5. **Test**
   - Test that errors are raised appropriately
   - Test retry behavior in jobs
   - Test error logging format

---

## Work Log

(To be filled during execution)

---

## Notes

Ruby exception best practices:
- Never rescue `Exception` (catches Interrupt, SystemExit)
- Prefer specific exceptions over StandardError
- Always re-raise if you don't know how to handle
- Log before re-raising for debugging

Rails patterns:
- Use `rescue_from` in controllers for API errors
- Use ActiveJob `retry_on` and `discard_on` for job errors
- Consider Honeybadger/Sentry for error tracking

---

## Links

- File: `app/jobs/scrape_metadata_job.rb` (lines 110-112)
- File: `app/models/domain.rb` (line 195)
- Doc: https://guides.rubyonrails.org/active_job_basics.html#exceptions
