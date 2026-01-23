# Task: Fix Rate Limit Test Setup

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-003-fix-rate-limit-test-setup` |
| Status | `todo` |
| Priority | `003` Medium |
| Created | `2026-01-23 12:05` |
| Started | |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

---

## Context

The rate limiting test in `spec/requests/comments_spec.rb` is failing because it manually writes to the Rails cache with a key that may not match what the `RateLimitable` concern generates.

The test writes:
```ruby
key = "rate_limit:#{site.id}:#{user.id}:comment:#{Time.current.beginning_of_hour.to_i}"
Rails.cache.write(key, 10, expires_in: 1.hour)
```

But the concern uses `Current.site` which may not be set in the test context:
```ruby
def rate_limit_key(user, action, site)
  site_id = site&.id || "global"
  "rate_limit:#{site_id}:#{user.id}:#{action}:#{Time.current.beginning_of_hour.to_i}"
end
```

This was discovered during the review phase of task 003-001-add-comments-views.

---

## Acceptance Criteria

- [ ] Rate limiting test correctly simulates hitting the rate limit
- [ ] Test properly sets up `Current.site` or uses correct cache key
- [ ] `spec/requests/comments_spec.rb` rate limiting test passes
- [ ] Quality gates pass

---

## Plan

1. **Investigate Current.site setup in request specs**
   - Files: `spec/requests/comments_spec.rb`, `spec/support/`
   - Actions: Check how Current.site is set in request specs

2. **Fix test setup** (choose one approach):
   - Option A: Ensure `Current.site` is properly set before the cache write
   - Option B: Use a shared helper method that matches the concern's key generation
   - Option C: Create comments via multiple POST requests instead of pre-filling cache

3. **Verify fix**
   - Run the specific failing test

---

## Work Log

### 2026-01-23 12:05 - Task Created

Created as follow-up from 003-001-add-comments-views review phase.
The rate limit test at line 161-168 fails because the cache key doesn't match.

---

## Testing Evidence

(To be filled during implementation)

---

## Notes

- The actual rate limiting functionality likely works in production
- This is a test setup issue, not a production bug

---

## Links

- Related: `003-001-add-comments-views` - Original discovery
- File: `spec/requests/comments_spec.rb:161-168`
- File: `app/models/concerns/rate_limitable.rb:77-80`
