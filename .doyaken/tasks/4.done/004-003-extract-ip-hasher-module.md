# Task: Extract IP Hashing Module

## Metadata

| Field       | Value                           |
| ----------- | ------------------------------- |
| ID          | `004-003-extract-ip-hasher`     |
| Status      | `done`                          |
| Completed   | `2026-02-01 21:11`              |
| Priority    | `003` Medium                    |
| Created     | `2026-02-01 19:20`              |
| Started     | `2026-02-01 21:02`              |
| Assigned To | |
| Labels      | `technical-debt`, `refactor`    |

---

## Context

**Intent**: IMPROVE

Identical `hash_ip` method found in multiple services:
- `BoostAttributionService` line 87-91
- `NetworkBoostService` line 85-89

Both contain the exact same IP hashing implementation:
```ruby
def hash_ip(ip)
  return nil if ip.blank?
  Digest::SHA256.hexdigest("#{ip}:#{Rails.application.secret_key_base}")
end
```

Flay identified this as mass*2=72 (identical).

Note: Two other services also have `hash_ip` methods but with DIFFERENT implementations:
- `ReferralAttributionService` (line 93-95): Plain SHA256, **no salt** - insecure
- `AffiliateUrlService` (line 81-85): SHA256 salted but **truncated to 16 chars**, different separator

These are OUT OF SCOPE for this task but should be addressed in a follow-up task to unify all IP hashing across the codebase.

---

## Acceptance Criteria

- [x] Create `IpHashable` module at `app/services/concerns/ip_hashable.rb`
- [x] Module provides `hash_ip(ip)` as a class method or instance method callable from class context
- [x] Refactor `BoostAttributionService` to include `IpHashable` and remove local `hash_ip` method
- [x] Refactor `NetworkBoostService` to include `IpHashable` and remove local `hash_ip` method
- [x] All existing tests pass without modification (or minimal test setup changes)
- [x] Quality gates pass (`bin/rubocop`, `bin/brakeman`, tests)

---

## Plan

### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Create `IpHashable` module at `app/services/concerns/ip_hashable.rb` | none | Directory and file don't exist |
| Module provides `hash_ip(ip)` as class method | none | Module needs to be created |
| Refactor `BoostAttributionService` to use `IpHashable` | none | Still has local `hash_ip` at lines 87-91 |
| Refactor `NetworkBoostService` to use `IpHashable` | none | Still has local `hash_ip` at lines 85-89 |
| All existing tests pass | full | Tests exist, test the public interface |
| Quality gates pass | TBD | Verify after implementation |

### Risks

- [ ] **Test compatibility**: Spec uses `described_class.send(:hash_ip, ...)` - Mitigated: `extend` preserves method access
- [ ] **Secret key dependency**: Module uses `Rails.application.secret_key_base` - Mitigated: Standard Rails pattern, available in all environments

### Steps

1. **Create services/concerns directory**
   - Run: `mkdir -p app/services/concerns`
   - Verify: Directory exists

2. **Create IpHashable module**
   - File: `app/services/concerns/ip_hashable.rb`
   - Create module with `hash_ip` as instance method (for use with `extend`)
   - Pattern: Simple module without `ActiveSupport::Concern` (not needed for single method)
   - Verify: `ruby -c app/services/concerns/ip_hashable.rb`

3. **Refactor BoostAttributionService**
   - File: `app/services/boost_attribution_service.rb`
   - Add `extend IpHashable` after `class << self` opening (line 10)
   - Remove `hash_ip` method definition (lines 87-91)
   - Verify: `bin/rspec spec/services/boost_attribution_service_spec.rb`

4. **Refactor NetworkBoostService**
   - File: `app/services/network_boost_service.rb`
   - Add `extend IpHashable` after `class << self` opening (line 8)
   - Remove `hash_ip` method definition (lines 85-89)
   - Verify: `bin/rspec spec/services/network_boost_service_spec.rb`

5. **Run quality gates**
   - Run: `bin/rubocop app/services/concerns/ip_hashable.rb app/services/boost_attribution_service.rb app/services/network_boost_service.rb`
   - Run: `bin/brakeman --only-files app/services/concerns/ip_hashable.rb,app/services/boost_attribution_service.rb,app/services/network_boost_service.rb`
   - Verify: All pass

### Checkpoints

| After Step | Verify |
|------------|--------|
| Step 2 | `ruby -c app/services/concerns/ip_hashable.rb` returns valid |
| Step 3 | `bin/rspec spec/services/boost_attribution_service_spec.rb` passes |
| Step 4 | `bin/rspec spec/services/network_boost_service_spec.rb` passes |
| Step 5 | All quality gates pass |

### Test Plan

- [ ] Unit: Existing specs cover `hash_ip` behavior through public methods (`record_click`, `record_impression`, etc.)
- [ ] Integration: No new tests needed - existing tests verify correct IP hashing behavior

### Docs to Update

- [ ] None required - internal refactoring only

---

## Notes

**In Scope:**
- Extract identical `hash_ip` from `BoostAttributionService` and `NetworkBoostService`
- Create shared concern in `app/services/concerns/`

**Out of Scope:**
- Unifying `ReferralAttributionService.hash_ip` (different implementation - no salt)
- Unifying `AffiliateUrlService.hash_ip` (different implementation - truncated)
- Creating follow-up task for unifying all IP hashing

**Assumptions:**
- The `app/services/concerns/` directory does not exist and will be created
- Both services use `hash_ip` as a class method (inside `class << self` blocks)
- The existing test specs access `hash_ip` via `described_class.send(:hash_ip, ...)` which will continue to work

**Edge Cases:**
- `hash_ip(nil)` returns `nil` - this behavior must be preserved
- `hash_ip("")` returns `nil` (blank check) - this behavior must be preserved

**Risks:**
- Low risk - simple extraction of identical code
- Test specs manually compute the hash in some places (`Digest::SHA256.hexdigest("192.168.1.1:#{Rails.application.secret_key_base}")`) - these will continue to work since the algorithm is unchanged
- Mitigation: Run affected specs after each service refactor

---

## Links

- Related: `app/services/boost_attribution_service.rb`
- Related: `app/services/network_boost_service.rb`

---

## Work Log

### 2026-02-01 21:00 - Task Expanded

- Intent: IMPROVE
- Scope: Extract identical `hash_ip` method from BoostAttributionService and NetworkBoostService into shared IpHashable concern
- Key files:
  - Create: `app/services/concerns/ip_hashable.rb`
  - Modify: `app/services/boost_attribution_service.rb`
  - Modify: `app/services/network_boost_service.rb`
- Complexity: Low
- Discovery: Found 4 total `hash_ip` implementations in codebase, but only 2 are identical. The other 2 (ReferralAttributionService, AffiliateUrlService) have different implementations and are out of scope.

### 2026-02-01 21:02 - Triage Complete

Quality gates:
- Lint: `bin/rubocop`
- Types: N/A (Ruby)
- Tests: `bundle exec rspec`
- Build: `bin/brakeman`

Task validation:
- Context: clear
- Criteria: specific
- Dependencies: none

Complexity:
- Files: few (create 1, modify 2)
- Risk: low

Verification:
- Source files exist at expected paths
- `hash_ip` methods found at lines 87 and 85 as documented
- Test specs exist for both services
- `app/services/concerns/` directory does not exist (will be created)

Ready: yes

### 2026-02-01 21:03 - Planning Complete

Gap analysis:
- All 4 acceptance criteria require implementation (status: none)
- Existing tests provide full coverage - no new tests needed

Risks identified:
- Test compatibility with `send(:hash_ip, ...)` - mitigated by using `extend`
- No architectural risks - straightforward extraction

Implementation plan:
- Steps: 5
- Files: 3 (1 new, 2 modified)
- Test coverage: Existing specs sufficient

Pattern decision:
- Use simple Ruby module (not `ActiveSupport::Concern`) since only providing single method
- Use `include IpHashable` inside `class << self` block to add method to singleton class

### 2026-02-01 21:05 - Implementation Complete

Step 1: Create services/concerns directory
- Created: `app/services/concerns/`
- Verification: pass

Step 2: Create IpHashable module
- Created: `app/services/concerns/ip_hashable.rb`
- Verification: `ruby -c` syntax OK

Step 3: Refactor BoostAttributionService
- Modified: `app/services/boost_attribution_service.rb`
- Added `include IpHashable` inside `class << self`
- Removed local `hash_ip` method (lines 87-91)
- Verification: 22 examples, 0 failures
- Deviation: Changed from `extend` to `include` inside `class << self` block - `extend` adds to metaclass, `include` adds to singleton class

Step 4: Refactor NetworkBoostService
- Modified: `app/services/network_boost_service.rb`
- Added `include IpHashable` inside `class << self`
- Removed local `hash_ip` method (lines 85-89)
- Verification: 19 examples, 0 failures

Step 5: Run quality gates
- Rubocop: 3 files inspected, no offenses detected
- Brakeman: No security issues
- Tests: 41 examples, 0 failures (both specs combined)

Commit: e212a21

### 2026-02-01 21:08 - Testing Complete

Tests written:
- `spec/services/concerns/ip_hashable_spec.rb` - 9 tests (unit)
  - SHA256 hash output validation
  - Secret key base salt verification
  - Hash consistency for same IP
  - Different hashes for different IPs
  - Edge cases: nil, empty string, whitespace
  - IPv4 and IPv6 format support

Quality gates:
- Lint: pass (1 file inspected, no offenses)
- Types: N/A (Ruby)
- Tests: pass (50 total, 9 new)
- Build: pass (Brakeman no security issues)

CI ready: yes

Commit: 9e8d606

### 2026-02-01 21:10 - Documentation Sync

Docs updated:
- None required - internal refactoring only

Inline comments:
- `app/services/concerns/ip_hashable.rb:1-11` - Module header documents purpose (privacy-preserving IP hashing), algorithm (SHA256 with secret salt), and usage pattern

Consistency: verified
- Code and inline docs match
- No external documentation references IP hashing
- Module is self-documenting with clear usage example

### 2026-02-01 21:11 - Review Complete

Findings:
- Blockers: 0
- High: 0
- Medium: 0
- Low: 0

Review passes:
- Correctness: pass - extracted method identical to original, all edge cases preserved
- Design: pass - follows Rails concern conventions, simple module appropriate for single method
- Security: pass - SHA256 with secret salt, no hardcoded secrets, no injection vectors
- Performance: pass - stateless pure function, no queries, efficient SHA256
- Tests: pass - 50 examples pass (9 new for IpHashable, 41 existing)

Quality gates verified:
- Lint: pass (4 files inspected, no offenses)
- Tests: pass (50 examples, 0 failures)
- Security: pass (Brakeman no issues)

All criteria met: yes
Follow-up tasks: none

Status: COMPLETE
