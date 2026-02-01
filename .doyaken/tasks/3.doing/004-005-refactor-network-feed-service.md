# Task: Refactor NetworkFeedService Query Duplication

## Metadata

| Field       | Value                                   |
| ----------- | --------------------------------------- |
| ID          | `004-005-refactor-network-feed-service` |
| Status      | `doing`                                 |
| Priority    | `003` Medium                            |
| Created     | `2026-02-01 19:20`                      |
| Started     | `2026-02-01 21:59`                      |
| Assigned To | `worker-1`                              |
| Labels      | `technical-debt`, `refactor`            |

---

## Context

**Intent**: IMPROVE

NetworkFeedService has significant code duplication that makes maintenance harder and increases risk of inconsistencies.

### Duplication Pattern 1: Network Sites Query (7 occurrences)
The following 5-line pattern is repeated in every public method:
```ruby
root_tenant = Tenant.find_by(slug: "root")
Site.unscoped
    .joins(:tenant)
    .where(tenants: { status: :enabled })
    .where(status: :enabled)
    .where.not(tenant: root_tenant)
```

Found in:
- `sites_directory` (lines 11-17)
- `recent_content` (lines 28-33)
- `trending_sites` (lines 50-57)
- `new_sites` (lines 77-83)
- `sites_by_topic` (lines 95-101)
- `recent_notes` (lines 114-119)
- `network_stats` (lines 136-141)

### Duplication Pattern 2: Recent Items Query (2 occurrences)
`recent_content` (lines 26-45) and `recent_notes` (lines 112-131) have nearly identical structure:
- Build `network_sites` subquery
- Query model (ContentItem/Note) with identical filtering:
  - `where(site: network_sites)`
  - `where.not(published_at: nil)`
  - `where(hidden_at: nil)`
  - `order(published_at: :desc)`
  - `offset/limit`
- Only difference: model class and `includes` associations

---

## Acceptance Criteria

- [x] Extract `network_sites_scope` private method that returns the base Site relation
- [x] Extract `root_tenant` private method to cache the root tenant lookup
- [x] Replace all 7 occurrences with calls to `network_sites_scope`
- [x] Extract `recent_publishable_items` private method parameterized by model class
- [x] Refactor `recent_content` and `recent_notes` to use the extracted method
- [x] All existing tests pass (16 tests)
- [x] Quality gates pass (`bin/rails standard`, `bin/rails rubocop`)
- [x] No behaviour changes - external API remains identical

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Extract `network_sites_scope` private method | none | Method doesn't exist; needs to be created |
| Extract `root_tenant` private method | none | Method doesn't exist; needs to be created |
| Replace all 7 occurrences with `network_sites_scope` | none | All 7 methods have inline duplication |
| Extract `recent_publishable_items` private method | none | Method doesn't exist; needs to be created |
| Refactor `recent_content` and `recent_notes` | none | Both use inline queries |
| All existing tests pass (16 tests) | full | Tests exist and pass currently |
| Quality gates pass | full | Code passes rubocop/standard |
| No behaviour changes | full | Pure extraction refactoring |

### Risks

- [ ] **Subtle query differences**: Mitigate by comparing each occurrence character-by-character before replacing
- [ ] **Class-level memoization**: `@root_tenant` is safe since `find_by` returns same result for immutable slug
- [ ] **Test coverage gaps**: 4/7 methods untested, but refactoring doesn't change behaviour - rely on existing 16 tests

### Implementation Steps

#### Phase A: Extract Helper Methods (Steps 1-2)

**Step 1: Extract `root_tenant` private method**
- File: `app/services/network_feed_service.rb`
- Change: Add after line 157 (after `cache_key` method):
  ```ruby
  def root_tenant
    @root_tenant ||= Tenant.find_by(slug: "root")
  end
  ```
- Verify: `bundle exec rspec spec/services/network_feed_service_spec.rb` (16 tests pass)

**Step 2: Extract `network_sites_scope` private method**
- File: `app/services/network_feed_service.rb`
- Change: Add after `root_tenant` method:
  ```ruby
  def network_sites_scope
    Site.unscoped
        .joins(:tenant)
        .where(tenants: { status: :enabled })
        .where(status: :enabled)
        .where.not(tenant: root_tenant)
  end
  ```
- Verify: Tests pass (no callers yet, just ensuring no syntax errors)

#### Phase B: Replace Network Sites Query (Steps 3-9)

**Step 3: Refactor `sites_directory`**
- File: `app/services/network_feed_service.rb`
- Change: Lines 11-17 → remove `root_tenant` variable and replace inline query with `network_sites_scope`
- Before:
  ```ruby
  root_tenant = Tenant.find_by(slug: "root")

  Site.unscoped
      .joins(:tenant)
      .where(tenants: { status: :enabled })
      .where(status: :enabled)
      .where.not(tenant: root_tenant)
  ```
- After:
  ```ruby
  network_sites_scope
  ```
- Verify: 5 `sites_directory` tests pass

**Step 4: Refactor `recent_content`**
- File: `app/services/network_feed_service.rb`
- Change: Lines 28-33 → remove `root_tenant` and `network_sites` variables, use `network_sites_scope` directly
- Verify: 8 `recent_content` tests pass

**Step 5: Refactor `trending_sites`**
- File: `app/services/network_feed_service.rb`
- Change: Lines 50-57 → remove `root_tenant` variable, use `network_sites_scope` as base for JOIN
- Note: This method adds additional clauses (JOIN, GROUP, ORDER) on top of base query
- Verify: Tests pass (no direct tests, but syntax/runtime check)

**Step 6: Refactor `new_sites`**
- File: `app/services/network_feed_service.rb`
- Change: Lines 77-83 → remove `root_tenant` variable, use `network_sites_scope`
- Verify: Tests pass

**Step 7: Refactor `sites_by_topic`**
- File: `app/services/network_feed_service.rb`
- Change: Lines 95-101 → remove `root_tenant` variable, use `network_sites_scope`
- Verify: Tests pass

**Step 8: Refactor `recent_notes`**
- File: `app/services/network_feed_service.rb`
- Change: Lines 114-119 → remove `root_tenant` and `network_sites` variables, use `network_sites_scope`
- Verify: Tests pass

**Step 9: Refactor `network_stats`**
- File: `app/services/network_feed_service.rb`
- Change: Lines 136-141 → remove `root_tenant` variable, use `network_sites_scope` for `network_sites`
- Verify: 4 `network_stats` tests pass

#### Phase C: Extract Recent Items Pattern (Steps 10-12)

**Step 10: Extract `recent_publishable_items` private method**
- File: `app/services/network_feed_service.rb`
- Change: Add after `network_sites_scope` method:
  ```ruby
  def recent_publishable_items(model_class:, includes:, limit:, offset:)
    model_class.unscoped
               .where(site: network_sites_scope)
               .where.not(published_at: nil)
               .where(hidden_at: nil)
               .order(published_at: :desc)
               .offset(offset)
               .limit(limit)
               .includes(includes)
               .to_a
  end
  ```
- Verify: Tests pass (no callers yet)

**Step 11: Refactor `recent_content` to use extracted method**
- File: `app/services/network_feed_service.rb`
- Change: Replace query body with:
  ```ruby
  recent_publishable_items(
    model_class: ContentItem,
    includes: [:source, site: :primary_domain],
    limit: limit,
    offset: offset
  )
  ```
- Verify: 8 `recent_content` tests pass

**Step 12: Refactor `recent_notes` to use extracted method**
- File: `app/services/network_feed_service.rb`
- Change: Replace query body with:
  ```ruby
  recent_publishable_items(
    model_class: Note,
    includes: [:user, site: :primary_domain],
    limit: limit,
    offset: offset
  )
  ```
- Verify: Tests pass

#### Phase D: Final Verification (Step 13)

**Step 13: Final quality checks**
- Run: `bundle exec rspec spec/services/network_feed_service_spec.rb` (16 tests)
- Run: `bundle exec rubocop app/services/network_feed_service.rb`
- Run: `bundle exec standardrb app/services/network_feed_service.rb`
- Verify: All pass

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 2 | Helper methods exist, tests still pass (16 green) |
| Step 9 | All 7 methods use `network_sites_scope`, tests pass |
| Step 12 | Both recent methods use `recent_publishable_items`, tests pass |
| Step 13 | Quality gates pass, no regressions |

### Test Plan

- [ ] Unit: Existing 16 tests cover `sites_directory`, `recent_content`, `network_stats`
- [ ] Integration: N/A - pure refactor with no behaviour change
- [ ] Manual: N/A - covered by existing tests

### Docs to Update

- [ ] None required - internal refactoring only

---

## Notes

**In Scope:**
- Extract `root_tenant` private method
- Extract `network_sites_scope` private method
- Extract `recent_publishable_items` private method
- Replace all duplicated code with calls to extracted methods

**Out of Scope:**
- Adding tests for untested methods (`trending_sites`, `new_sites`, `sites_by_topic`, `recent_notes`)
- Changing public API signatures
- Performance optimizations beyond removing redundant `Tenant.find_by` calls
- Refactoring cache keys or caching strategy

**Assumptions:**
- Class methods (`class << self`) can use instance variable memoization with `@root_tenant`
- The `root` tenant slug is stable and won't change
- All 7 methods need the exact same base query (no variations)

**Edge Cases:**
- Root tenant doesn't exist: Current behaviour returns empty results; this should be preserved
- All tenants disabled: Returns empty results; preserved
- Thread safety: Class-level memoization is safe since `find_by` returns same result

**Risks:**
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Subtle query differences | Low | Medium | Carefully compare each occurrence before replacing |
| Memoization causing stale data | Low | Medium | Use `||=` only for immutable lookups like root tenant |
| Test coverage gaps | Medium | Low | Existing tests cover main paths; run full suite after each step |

**Test Coverage Status:**
- Covered: `sites_directory`, `recent_content`, `network_stats` (16 tests)
- Not covered: `trending_sites`, `new_sites`, `sites_by_topic`, `recent_notes`
- Strategy: Rely on existing tests; refactoring should not change behaviour

---

## Links

- Related: `app/services/network_feed_service.rb`
- Tests: `spec/services/network_feed_service_spec.rb`

---

## Work Log

### 2026-02-01 22:10 - Implementation Complete

**Phase A: Extract Helper Methods (Steps 1-2)**
- Step 1: Extracted `root_tenant` private method
  - Initially added memoization `@root_tenant ||=` per plan
  - Removed memoization after test failure (class-level instance var persists across tests)
  - Files modified: `app/services/network_feed_service.rb`
  - Verification: 17 tests pass

- Step 2: Extracted `network_sites_scope` private method
  - Files modified: `app/services/network_feed_service.rb`
  - Verification: 17 tests pass

**Phase B: Replace Network Sites Query (Steps 3-9)**
- Steps 3-9: Replaced all 7 occurrences with `network_sites_scope`
  - `sites_directory`, `recent_content`, `trending_sites`, `new_sites`
  - `sites_by_topic`, `recent_notes`, `network_stats`
  - Verification after each step: all tests pass

**Phase C: Extract Recent Items Pattern (Steps 10-12)**
- Step 10: Extracted `recent_publishable_items` private method
  - Parameterized by model_class, includes, limit, offset

- Steps 11-12: Refactored `recent_content` and `recent_notes` to use extracted method
  - Verification: 17 tests pass

**Phase D: Final Verification (Step 13)**
- Tests: 17 examples, 0 failures
- Rubocop: 1 file inspected, no offenses detected
- Commit: `34c3af1`

**Deviation from Plan:**
- Removed `@root_tenant` memoization due to test isolation issues
- Reason: Class-level instance variables persist across test runs, causing stale root_tenant references

**Summary:**
- Lines: 159 → 133 (26 lines removed, ~16% reduction)
- Extracted methods: 3 (`root_tenant`, `network_sites_scope`, `recent_publishable_items`)
- Query duplications eliminated: 7 (network_sites) + 2 (recent items)
- All acceptance criteria met

---

### 2026-02-01 22:01 - Planning Complete

**Gap Analysis Summary:**
- 6/8 criteria have gaps (need implementation)
- 2/8 criteria already satisfied (tests pass, quality gates pass)

**Plan Details:**
- Steps: 13 (3 extraction + 7 replacements + 2 refactors + 1 verification)
- Phases: 4 (A: Extract helpers, B: Replace queries, C: Extract pattern, D: Verify)
- Risks: 3 identified (all low-medium likelihood with clear mitigation)
- Test coverage: Moderate (16 tests covering 3/7 methods; sufficient for refactoring)

**Key Decisions:**
1. Memoize `root_tenant` with `@root_tenant ||=` for efficiency
2. Consolidate 7 occurrences into `network_sites_scope`
3. Extract `recent_publishable_items` parameterized by model class
4. Incremental approach: verify tests after each step

---

### 2026-02-01 21:59 - Triage Complete

Quality gates:
- Lint: `bundle exec rubocop --format progress --display-cop-names`
- Types: N/A (Ruby)
- Tests: `bundle exec rspec spec/services/network_feed_service_spec.rb`
- Build: `bin/quality` (full suite)

Task validation:
- Context: clear
- Criteria: specific
- Dependencies: none

Complexity:
- Files: few (1 source, 1 test)
- Risk: low

Ready: yes

---

### 2026-02-01 21:58 - Task Expanded

- Intent: IMPROVE (refactoring to reduce duplication)
- Scope: Extract 3 private methods to eliminate 7 occurrences of duplicated network sites query and 2 occurrences of recent items pattern
- Key files:
  - `app/services/network_feed_service.rb` (159 lines, 7 public methods)
  - `spec/services/network_feed_service_spec.rb` (168 lines, 16 tests)
- Complexity: Low-Medium
  - Low risk: Pure extraction refactoring with good test coverage on main paths
  - Medium scope: 7 methods need updates, 13 planned steps
- Analysis findings:
  - Original task said 6 occurrences; actual count is 7
  - Tests exist for 3/7 methods; sufficient for refactoring validation
  - No behaviour changes expected; public API unchanged
