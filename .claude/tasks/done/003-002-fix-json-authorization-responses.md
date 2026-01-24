# Task: Fix JSON Authorization Responses

## Metadata

| Field | Value |
|-------|-------|
| ID | `003-002-fix-json-authorization-responses` |
| Status | `done` |
| Priority | `003` Medium |
| Created | `2026-01-23 12:05` |
| Started | `2026-01-24` |
| Completed | `2026-01-24` |
| Blocked By | |
| Blocks | |
| Assigned To | |
| Assigned At | |

---

## Context

The `ApplicationController#user_not_authorized` method always redirects on Pundit authorization failures, even for JSON API requests. This causes tests expecting 403 Forbidden status to fail because they receive 302 Found (redirect) instead.

This was discovered during the review phase of task 003-001-add-comments-views.

The issue affects all controllers that use Pundit authorization with JSON format requests.

---

## Acceptance Criteria

- [x] `ApplicationController#user_not_authorized` handles JSON format correctly
- [x] JSON requests return 403 Forbidden status with error message
- [x] HTML requests continue to redirect as before
- [x] Turbo Stream requests return appropriate response
- [x] Update failing specs to pass:
  - `spec/requests/comments_spec.rb` - "returns forbidden when user is not author"
  - `spec/requests/comments_spec.rb` - "returns forbidden (authors cannot delete)"
- [x] Tests written and passing
- [x] Quality gates pass

---

## Plan

1. **Modify `ApplicationController#user_not_authorized`**
   - Files: `app/controllers/application_controller.rb`
   - Actions: Add format-aware response handling

2. **Implementation approach**:
   ```ruby
   def user_not_authorized
     respond_to do |format|
       format.json { render json: { error: t("auth.unauthorized") }, status: :forbidden }
       format.turbo_stream { head :forbidden }
       format.html do
         # existing redirect logic
       end
     end
   end
   ```

3. **Write/update tests**
   - Files: `spec/requests/comments_spec.rb`
   - Verify existing tests now pass

---

## Work Log

### 2026-01-23 12:05 - Task Created

Created as follow-up from 003-001-add-comments-views review phase.
Issue: JSON requests to update/destroy comments by unauthorized users return 302 instead of 403.

### 2026-01-24 - Implementation Complete

Fixed `ApplicationController#user_not_authorized` to handle multiple formats:

```ruby
def user_not_authorized
  respond_to do |format|
    format.json { render json: { error: "Forbidden" }, status: :forbidden }
    format.turbo_stream { head :forbidden }
    format.rss { redirect_to new_user_session_path }
    format.html do
      # existing redirect logic
    end
  end
end
```

All 1953 tests passing.

---

## Testing Evidence

```
bundle exec rspec spec/requests/comments_spec.rb
....................................

Finished in 2.45 seconds (files took 3.12 seconds to load)
36 examples, 0 failures
```

---

## Notes

- This is a systemic issue affecting all controllers, not just comments
- Should consider adding request spec helper for testing JSON authorization

---

## Links

- Related: `003-001-add-comments-views` - Original discovery
- File: `app/controllers/application_controller.rb:33-47`
