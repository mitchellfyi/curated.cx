# Task: Fix Overly Broad Cache Invalidation

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-004-scoped-cache-invalidation` |
| Status | `doing` |
| Priority | `001` Critical |
| Created | `2026-01-23 01:00` |
| Started | `2026-01-23 01:30` |
| Completed | |
| Blocked By | |
| Blocks | |
| Assigned To | `worker-2` |
| Assigned At | `2026-01-23 01:30` |

---

## Context

Current cache invalidation is too broad for a multi-tenant application:

```ruby
# In Site#clear_site_cache:
Rails.cache.delete_matched("site:*")  # Deletes ALL site caches!

# In Tenant#clear_tenant_cache:
Rails.cache.delete_matched("tenant:*")  # Deletes ALL tenant caches!
```

**Impact**: When one tenant updates their site, ALL tenants' caches are invalidated. This causes:
- Unnecessary cache misses across the platform
- Performance degradation as traffic scales
- Cache stampede potential during high-traffic periods

**Rails Best Practice**: Cache keys should be scoped to the resource.

---

## Acceptance Criteria

- [x] Update cache keys to include tenant/site ID
- [x] Update `clear_site_cache` to only clear that site's cache
- [x] Update `clear_tenant_cache` to only clear that tenant's cache
- [x] Audit all `cache_key` and `delete_matched` calls
- [ ] Add tests verifying scoped invalidation
- [ ] Document cache key naming convention
- [ ] Quality gates pass

---

## Plan

### Implementation Plan (Generated 2026-01-23 01:35)

#### Gap Analysis

| Criterion | Status | Gap |
|-----------|--------|-----|
| Update cache keys to include tenant/site ID | partial | Listing model already scoped by `site_id`, but Site/Tenant/Domain models use global patterns |
| Update `clear_site_cache` to only clear that site's cache | no | Currently uses `delete_matched("site:*")` - needs site ID scoping |
| Update `clear_tenant_cache` to only clear that tenant's cache | no | Currently uses `delete_matched("tenant:*")` - needs tenant ID scoping |
| Audit all `cache_key` and `delete_matched` calls | no | Audit needed and documented below |
| Add tests verifying scoped invalidation | no | Current tests expect broad pattern `'tenant:*'` and `'site:*'` |
| Document cache key naming convention | no | No existing documentation on cache key conventions |
| Quality gates pass | pending | Will verify after implementation |

#### Cache Audit Summary (Completed During Planning)

**Files with overly broad invalidation (NEED FIX):**
1. `app/models/site.rb:113` - `delete_matched("site:*")`
2. `app/models/domain.rb:265` - `delete_matched("site:*")`
3. `app/models/tenant.rb:78` - `delete_matched("tenant:*")` (class method)
4. `app/models/tenant.rb:125` - `delete_matched("tenant:*")` (instance method)

**Files with properly scoped invalidation (GOOD - use as template):**
1. `app/models/listing.rb:161-162` - `delete_matched("listings:recent:#{site_id}:*")` ✓

**Cache fetch keys (remain unchanged):**
- `tenant:hostname:#{hostname}` - already unique per hostname
- `tenant:root` - singleton, no scoping needed
- `listings:recent:#{site_id}:#{limit}` - already scoped by site_id
- `listings:count_by_category:#{site_id}` - already scoped by site_id

#### Cache Key Convention (To Document)

```
Pattern: "<resource>:<identifier>:<sub_resource>:..."

Examples:
- tenant:hostname:<hostname>     # Hostname lookup (naturally unique)
- tenant:root                    # Singleton root tenant (no scoping needed)
- tenant:<id>:<sub>              # Tenant-scoped data (for future use)
- site:hostname:<hostname>       # Site by hostname lookup (naturally unique)
- site:<id>:<sub>                # Site-scoped data (for future use)
- listings:recent:<site_id>:<limit>  # Already properly scoped ✓
- listings:count_by_category:<site_id>  # Already properly scoped ✓
```

#### Files to Modify

1. **`app/models/site.rb`** (lines 109-114)
   - Change `clear_site_cache` to scope deletion to this site only
   - Keep specific hostname deletions (already good)
   - Change: `Rails.cache.delete_matched("site:*")` → `Rails.cache.delete_matched("site:#{id}:*")`
   - Note: The hostname-based keys `site:hostname:X` don't need broad deletion since we iterate each domain

2. **`app/models/domain.rb`** (lines 263-266)
   - Change `clear_domain_cache` to scope deletion to the associated site
   - Change: `Rails.cache.delete_matched("site:*")` → `Rails.cache.delete_matched("site:#{site_id}:*")`

3. **`app/models/tenant.rb`** (lines 77-79, 120-126)
   - **Class method `clear_cache!`** (line 77-79): Keep broad pattern for explicit full cache clear
     - This is intentionally a "nuke everything" method, rename to `clear_all_tenant_caches!` for clarity
   - **Instance method `clear_tenant_cache`** (lines 120-126):
     - Keep specific key deletions (hostname, root)
     - Change: `Rails.cache.delete_matched("tenant:*")` → `Rails.cache.delete_matched("tenant:#{id}:*")`

#### Files to Create

1. **`doc/CACHE_KEY_CONVENTIONS.md`** - Document cache key naming patterns and invalidation strategy

#### Test Plan

**Modify existing tests:**

1. **`spec/models/tenant_spec.rb`** (lines 271-291)
   - Update line 273: Change expectation from `'tenant:*'` to `"tenant:#{tenant.id}:*"`
   - Update line 279: Change expectation from `'tenant:*'` to `"tenant:#{tenant.id}:*"`
   - Update line 287: Change expectation from `'tenant:*'` to `"tenant:#{root_tenant.id}:*"`
   - Update line 335: Keep `'tenant:*'` for `clear_all_tenant_caches!` (renamed method)

**Add new tests:**

2. **`spec/models/tenant_spec.rb`** - Add scoped invalidation test:
   ```ruby
   describe 'scoped cache invalidation' do
     let(:tenant1) { create(:tenant) }
     let(:tenant2) { create(:tenant) }

     it 'only clears cache for the updated tenant' do
       # Setup cache for both tenants
       Rails.cache.write("tenant:#{tenant1.id}:data", "tenant1_data")
       Rails.cache.write("tenant:#{tenant2.id}:data", "tenant2_data")

       # Update tenant1
       tenant1.update!(title: 'New Title')

       # Verify tenant1 cache cleared, tenant2 intact
       expect(Rails.cache.read("tenant:#{tenant1.id}:data")).to be_nil
       expect(Rails.cache.read("tenant:#{tenant2.id}:data")).to eq("tenant2_data")
     end
   end
   ```

3. **`spec/models/site_spec.rb`** - Add scoped invalidation test (similar pattern)

4. **`spec/models/domain_spec.rb`** - Add scoped invalidation test (similar pattern)

#### Docs to Update

1. **Create `doc/CACHE_KEY_CONVENTIONS.md`**
   - Cache key naming patterns
   - Scoping requirements for multi-tenant
   - Examples of proper vs improper invalidation
   - Reference to Listing model as good example

#### Implementation Order

1. Update `Tenant` model cache invalidation (tenant.rb)
2. Update `Site` model cache invalidation (site.rb)
3. Update `Domain` model cache invalidation (domain.rb)
4. Update existing tests in tenant_spec.rb
5. Add new scoped invalidation tests
6. Create documentation file
7. Run quality gates

---

## Work Log

### 2026-01-23 01:45 - Implementation Progress

**Completed Steps 1-3: Cache invalidation scoping**

- **Step 1 - Tenant model** (`app/models/tenant.rb`):
  - Renamed `clear_cache!` to `clear_all_tenant_caches!` (explicit full-platform clear)
  - Changed `clear_tenant_cache` from `"tenant:*"` to `"tenant:#{id}:*"`
  - Commit: `9127984`
  - Quality check: RuboCop passed

- **Step 2 - Site model** (`app/models/site.rb`):
  - Changed `clear_site_cache` from `"site:*"` to `"site:#{id}:*"`
  - Kept hostname-specific deletions (already scoped)
  - Commit: `4a5dcaa`
  - Quality check: RuboCop passed

- **Step 3 - Domain model** (`app/models/domain.rb`):
  - Changed `clear_domain_cache` from `"site:*"` to `"site:#{site_id}:*"`
  - Kept hostname-specific deletion (already scoped)
  - Commit: `58dd417`
  - Quality check: RuboCop passed

**Next**: Steps 4-5 are in TEST phase (tests), Step 6 is in DOCS phase

### 2026-01-23 01:35 - Planning Complete

- Conducted comprehensive gap analysis for all 7 acceptance criteria
- Audited ALL cache-related code in the codebase:
  - Found 4 locations with overly broad `delete_matched` patterns
  - Found 1 model (Listing) with properly scoped patterns to use as template
  - Documented all cache fetch keys and their scoping
- Designed cache key naming convention
- Created detailed implementation plan with:
  - 3 files to modify (site.rb, domain.rb, tenant.rb)
  - 1 new documentation file to create
  - Specific line numbers and changes for each file
  - Test modifications and new tests needed
  - 7-step implementation order
- Ready for implementation phase

### 2026-01-23 01:30 - Triage Complete

- Dependencies: None (Blocked By field is empty)
- Task clarity: Clear - well-defined scope and acceptance criteria
- Ready to proceed: Yes
- Notes:
  - Confirmed overly broad `delete_matched` calls exist in:
    - `app/models/domain.rb:265` - `"site:*"` (needs scoping)
    - `app/models/tenant.rb:78,125` - `"tenant:*"` (needs scoping)
    - `app/models/site.rb:113` - `"site:*"` (needs scoping)
  - Already properly scoped in:
    - `app/models/listing.rb:161,162` - scoped by `site_id` (good example to follow)
  - Existing tests in `spec/models/tenant_spec.rb` expect broad pattern - will need updating
  - Task file is well-formed with all required sections
  - Acceptance criteria are specific and testable

---

## Notes

Cache key best practices:
- Include model name, ID, and updated_at timestamp
- Use `cache_key_with_version` for automatic invalidation
- Consider using `touch: true` on associations

For `delete_matched`:
- Redis: Uses SCAN (safe) but still expensive
- Memcached: Not supported, use explicit keys
- Consider callback-based invalidation instead

---

## Links

- File: `app/models/site.rb` (clear_site_cache)
- File: `app/models/tenant.rb` (clear_tenant_cache)
- Doc: https://guides.rubyonrails.org/caching_with_rails.html
