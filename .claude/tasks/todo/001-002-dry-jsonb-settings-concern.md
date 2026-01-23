# Task: Extract JsonbSettingsAccessor Concern (DRY Violation)

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-002-dry-jsonb-settings-concern` |
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

The `Tenant` and `Site` models both have **identical** implementations of JSONB settings accessor methods:

```ruby
# Both models have these ~40 lines duplicated:
def setting(key, default = nil)
  keys = key.to_s.split(".")
  value = settings&.dig(*keys.map(&:to_s))
  value.nil? ? default : value
end

def update_setting(key, value)
  keys = key.to_s.split(".")
  current = settings || {}
  # ... navigate nested structure, set value, save
end
```

This violates DRY principle and creates maintenance burden - any fix must be applied twice.

**Rails Best Practice**: Use concerns for shared model behavior.

---

## Acceptance Criteria

- [ ] Create `app/models/concerns/jsonb_settings_accessor.rb`
- [ ] Extract `setting(key, default)` method
- [ ] Extract `update_setting(key, value)` method
- [ ] Extract `settings_with_defaults` method if present
- [ ] Include concern in `Tenant` model
- [ ] Include concern in `Site` model
- [ ] Remove duplicate code from both models
- [ ] All existing tests pass
- [ ] Add spec for the concern itself
- [ ] Quality gates pass

---

## Plan

1. **Analyze Current Implementation**
   - Files: `app/models/tenant.rb`, `app/models/site.rb`
   - Document exact methods and their signatures

2. **Create Concern**
   - File: `app/models/concerns/jsonb_settings_accessor.rb`
   - Use `extend ActiveSupport::Concern`
   - Make configurable for different column names if needed

3. **Update Models**
   - Include concern in Tenant
   - Include concern in Site
   - Remove duplicated methods

4. **Test**
   - File: `spec/models/concerns/jsonb_settings_accessor_spec.rb`
   - Test setting/getting nested keys
   - Test default values
   - Test update persistence

---

## Work Log

(To be filled during execution)

---

## Notes

Related patterns in Rails:
- `ActiveSupport::Concern` for shared model behavior
- `store_accessor` for simpler JSONB access (but doesn't support nesting)
- Consider adding `class_attribute :settings_column` for flexibility

---

## Links

- File: `app/models/tenant.rb` (lines 73-112)
- File: `app/models/site.rb` (lines 73-112)
- Doc: https://api.rubyonrails.org/classes/ActiveSupport/Concern.html
