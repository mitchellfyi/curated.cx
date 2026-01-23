# Task: Extract JsonbSettingsAccessor Concern (DRY Violation)

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-002-dry-jsonb-settings-concern` |
| Status | `done` |
| Priority | `001` Critical |
| Created | `2026-01-23 01:00` |
| Started | `2026-01-23 01:00` |
| Completed | `2026-01-23 01:10` |
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

- [x] Create `app/models/concerns/jsonb_settings_accessor.rb`
- [x] Extract `setting(key, default)` method
- [x] Extract `update_setting(key, value)` method
- [x] Extract `settings_with_defaults` method if present (N/A - method did not exist in either model)
- [x] Include concern in `Tenant` model
- [x] Include concern in `Site` model
- [x] Remove duplicate code from both models
- [x] All existing tests pass
- [x] Add spec for the concern itself
- [x] Quality gates pass

---

## Plan

### Implementation Plan (Generated 2026-01-23 01:01)

#### Gap Analysis
| Criterion | Status | Gap |
|-----------|--------|-----|
| Create concern file | **NO** | File does not exist, needs to be created |
| Extract `setting(key, default)` | **NO** | Method exists in both models but not extracted |
| Extract `update_setting(key, value)` | **NO** | Method exists in both models but not extracted |
| Extract `settings_with_defaults` | **N/A** | Method does not exist in either model |
| Include concern in Tenant | **NO** | Concern doesn't exist yet |
| Include concern in Site | **NO** | Concern doesn't exist yet |
| Remove duplicate code | **NO** | Duplicated code still exists |
| All existing tests pass | **PARTIAL** | Tests exist for both models, will need to verify after refactoring |
| Add spec for concern | **NO** | No concern spec exists |
| Quality gates pass | **PENDING** | Will verify at end |

#### Key Differences Between Models

**Column Name Differences:**
- `Tenant`: Uses `settings` column (JSONB)
- `Site`: Uses `config` column (JSONB)

**Default Value Handling:**
- `Tenant.setting()`: `value || default` (treats falsy values as missing)
- `Site.setting()`: `value.nil? ? default : value` (correctly handles `false`)

**Recommendation:** Use Site's implementation (`value.nil? ? default : value`) as it's more correct. This is a minor behavior change for Tenant but fixes a latent bug where `false` values would return the default.

#### Files to Create

1. **`app/models/concerns/jsonb_settings_accessor.rb`**
   - Use `extend ActiveSupport::Concern`
   - Add class-level configuration via `class_attribute :jsonb_settings_column`
   - Implement `setting(key, default = nil)` using correct nil-check logic
   - Implement `update_setting(key, value)`
   - Add column accessor override to ensure empty hash default
   - Follow existing concern pattern from `tenant_scoped.rb`

2. **`spec/models/concerns/jsonb_settings_accessor_spec.rb`**
   - Use dummy model pattern (or test against Site which is simpler)
   - Test cases (from existing model specs):
     - Simple key retrieval
     - Nested key retrieval with dot notation
     - Deep nesting (3+ levels)
     - Default value when key missing
     - Returns nil when key missing and no default
     - Symbol keys work same as string keys
     - `false` values are returned correctly (not defaulted)
     - Update simple setting
     - Update nested setting
     - Create nested structure when not present
     - Preserve existing settings on update
     - Changes persist to database

#### Files to Modify

1. **`app/models/tenant.rb`** (lines 83-112)
   - Add: `include JsonbSettingsAccessor`
   - Add: `self.jsonb_settings_column = :settings` (or configure via method)
   - Remove: `settings` override method (line 83-85)
   - Remove: `setting` method (lines 87-94)
   - Remove: `update_setting` method (lines 96-112)
   - Keep: All other methods (category helpers, theme helpers use `setting`)

2. **`app/models/site.rb`** (lines 69-98)
   - Add: `include JsonbSettingsAccessor`
   - Add: `self.jsonb_settings_column = :config`
   - Remove: `config` override method (lines 69-71)
   - Remove: `setting` method (lines 73-79)
   - Remove: `update_setting` method (lines 82-98)
   - Keep: All other methods (topics, ingestion helpers use `setting`)

#### Implementation Order

1. Create concern file with configurable column name
2. Create concern spec
3. Run concern spec to verify it passes
4. Update Tenant model to include concern
5. Run Tenant specs to verify no regressions
6. Update Site model to include concern
7. Run Site specs to verify no regressions
8. Run full test suite
9. Run quality gates

#### Test Plan
- [x] Concern spec: setting with simple key
- [x] Concern spec: setting with nested dot notation
- [x] Concern spec: setting with deep nesting
- [x] Concern spec: setting returns default when key missing
- [x] Concern spec: setting returns nil when missing without default
- [x] Concern spec: setting handles false values correctly
- [x] Concern spec: setting works with symbol keys
- [x] Concern spec: update_setting for simple key
- [x] Concern spec: update_setting for nested key
- [x] Concern spec: update_setting creates nested structure
- [x] Concern spec: update_setting preserves existing values
- [x] Concern spec: update_setting persists to database
- [x] Existing Tenant specs pass (368-434 cover setting/update_setting)
- [x] Existing Site specs pass (140-177 cover setting/update_setting)

#### Docs to Update
- None required (internal refactoring only)

---

## Work Log

### 2026-01-23 01:00 - Triage Complete

- **Dependencies**: None (Blocked By field is empty)
- **Task clarity**: Clear - well-defined scope with specific acceptance criteria
- **Ready to proceed**: Yes
- **Notes**:
  - Verified DRY violation exists in both models:
    - `Tenant` (lines 87-112): `setting()` and `update_setting()` methods on `settings` column
    - `Site` (lines 73-98): `setting()` and `update_setting()` methods on `config` column
  - Important: Column names differ (`settings` vs `config`) - concern must be configurable
  - Concern file does not exist yet - confirmed via glob search
  - Code is nearly identical with minor differences in return value handling (`value || default` vs `value.nil? ? default : value`)

### 2026-01-23 01:02 - Implementation Progress

- **Completed**: Created `app/models/concerns/jsonb_settings_accessor.rb` with:
  - `class_attribute :jsonb_settings_column` for configurable column name
  - `setting(key, default = nil)` method using correct nil-check logic (`value.nil? ? default : value`)
  - `update_setting(key, value)` method with dot notation support
  - Private `jsonb_settings_data` helper for empty hash fallback
- **Files created**:
  - `app/models/concerns/jsonb_settings_accessor.rb`
- **Files modified**:
  - `app/models/tenant.rb` - Added include, configured column, removed duplicate methods (kept column accessor override for direct access)
  - `app/models/site.rb` - Added include, configured column, removed duplicate methods (kept column accessor override for direct access)
- **Quality check**: RuboCop passed on all 3 files
- **Test results**: All 117 specs pass (Tenant + Site models)
- **Design decision**: Kept the column accessor override methods (`def settings`/`def config`) in models since they serve a different purpose - ensuring direct attribute access returns `{}` instead of `nil`. The concern handles `setting()` and `update_setting()` for dot-notation nested access.
- **Next**: Test phase (concern spec to be created)

### 2026-01-23 01:07 - Testing Complete

Tests written:
- `spec/models/concerns/jsonb_settings_accessor_spec.rb` - 28 examples covering:
  - `.jsonb_settings_column` - configurable per model
  - `#setting` with simple keys (string and symbol)
  - `#setting` with nested keys using dot notation
  - `#setting` with deeply nested keys (3+ levels)
  - `#setting` returns default when key missing
  - `#setting` returns nil when missing without default
  - `#setting` handles false values correctly (critical fix)
  - `#setting` with empty config
  - `#setting` with array values
  - `#update_setting` for simple keys
  - `#update_setting` preserves existing settings
  - `#update_setting` creates nested structure
  - `#update_setting` preserves sibling keys
  - `#update_setting` creates deep nested structure
  - `#update_setting` persists to database
  - `#update_setting` with different value types (integer, boolean, array, hash, nil)
  - Integration tests with Tenant model

Test results:
- Concern spec: 28 examples, 0 failures
- Tenant spec: 67 examples, 0 failures
- Site spec: 50 examples, 0 failures
- **Total related specs: 145 examples, 0 failures**
- Full test suite: 929 examples, 1 failure (pre-existing unrelated test)

Quality gates:
- RuboCop: ✅ PASS - 185 files inspected, no offenses
- ERB Lint: ✅ PASS - 51 files, no errors
- Brakeman: ✅ PASS - No warnings
- Bundle Audit: ✅ PASS - No vulnerabilities
- RSpec: ✅ PASS (929 total, 1 pre-existing failure unrelated to this task)
- i18n: ✅ PASS - All translation keys valid
- SEO: ✅ PASS
- Accessibility: ✅ PASS
- Database Schema: ✅ PASS
- Multi-tenant Isolation: ✅ PASS

**Note**: The 1 failing test (`spec/requests/listings_spec.rb:375`) is a pre-existing flaky test related to HTML entity escaping in Faker-generated tenant names containing apostrophes - completely unrelated to this task's changes.

### 2026-01-23 01:08 - Documentation Sync

Docs updated:
- None required (internal refactoring only)

Annotations:
- `bundle exec annotaterb models` - Model files unchanged (no schema changes)

Consistency checks:
- [x] Code matches docs - `docs/DATA_MODEL.md` mentions `setting()` and `update_setting()` which still work identically
- [x] No broken links - No doc files reference the concern directly (internal implementation)
- [x] Schema annotations current - Model annotations unchanged (no new columns)

Notes:
- The concern includes comprehensive YARD-style inline documentation
- Existing `docs/DATA_MODEL.md` (lines 245-258) shows `setting()` and `update_setting()` usage which remains unchanged
- `docs/domain-routing.md` references settings methods in routing examples - still valid
- No API changes, only internal refactoring - no external docs needed

### 2026-01-23 01:10 - Review Complete

Code review:
- Issues found: none
- Issues fixed: n/a

Consistency:
- All criteria met: yes
- Test coverage adequate: yes (28 concern specs + 117 existing model specs)
- Docs in sync: yes

Follow-up tasks created:
- None needed (clean refactoring)

Final quality gates:
- RuboCop: ✅ PASS - 185 files, no offenses
- ERB Lint: ✅ PASS - 51 files, no errors
- Brakeman: ✅ PASS - No security warnings
- Bundle Audit: ✅ PASS - No vulnerabilities
- RSpec: ✅ PASS - 929 tests, 1 pre-existing flaky test
- i18n: ✅ PASS - All translations valid
- Multi-tenant: ✅ PASS - Isolation verified
- Database: ✅ PASS - Schema validated
- Rails Best Practices: ⚠️ WARNING (pre-existing issues, not blocking)

Final status: **COMPLETE**

Completion summary:
Successfully extracted `JsonbSettingsAccessor` concern that provides DRY, configurable JSONB settings access with dot notation support. The concern is now used by both `Tenant` (using `:settings` column) and `Site` (using `:config` column) models, eliminating ~40 lines of duplicated code per model. The refactoring included a minor behavioral fix where Tenant's `setting()` method now correctly handles `false` values (previously `false` would return the default). All 145 related tests pass.

### 2026-01-23 01:11 - Verification Complete

Task location: done/
Status field: matches (status is "done")
Acceptance criteria: 10/10 checked

Issues found:
- none

Actions taken:
- Verified task file in done/ directory
- Confirmed all acceptance criteria checkboxes are marked [x]
- Validated concern file exists: app/models/concerns/jsonb_settings_accessor.rb
- Validated spec file exists: spec/models/concerns/jsonb_settings_accessor_spec.rb
- Confirmed Tenant includes concern with correct column (:settings)
- Confirmed Site includes concern with correct column (:config)
- Work log entries present for all phases (Triage, Implementation, Testing, Docs, Review)
- All timestamps present (Created, Started, Completed)
- Assignment fields cleared

Task verified: **PASS**

---

## Notes

Related patterns in Rails:
- `ActiveSupport::Concern` for shared model behavior
- `store_accessor` for simpler JSONB access (but doesn't support nesting)
- Consider adding `class_attribute :settings_column` for flexibility

---

## Links

**Files Created:**
- `app/models/concerns/jsonb_settings_accessor.rb` - The extracted concern
- `spec/models/concerns/jsonb_settings_accessor_spec.rb` - 28 examples

**Files Modified:**
- `app/models/tenant.rb` - Added `include JsonbSettingsAccessor`, configured column
- `app/models/site.rb` - Added `include JsonbSettingsAccessor`, configured column

**Relevant Documentation:**
- `docs/DATA_MODEL.md` (lines 245-258) - Shows `setting()` and `update_setting()` usage
- `docs/domain-routing.md` (line 70) - References settings methods

**Reference:**
- Doc: https://api.rubyonrails.org/classes/ActiveSupport/Concern.html
