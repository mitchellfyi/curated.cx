# Task: Fix Overly Broad Cache Invalidation

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-004-scoped-cache-invalidation` |
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

- [ ] Update cache keys to include tenant/site ID
- [ ] Update `clear_site_cache` to only clear that site's cache
- [ ] Update `clear_tenant_cache` to only clear that tenant's cache
- [ ] Audit all `cache_key` and `delete_matched` calls
- [ ] Add tests verifying scoped invalidation
- [ ] Document cache key naming convention
- [ ] Quality gates pass

---

## Plan

1. **Audit Cache Usage**
   - Find all `Rails.cache` calls
   - Find all `cache_key` methods
   - Document current key patterns

2. **Define Cache Key Convention**
   ```ruby
   # Pattern: "resource:id:sub_resource:sub_id:..."
   # Example: "tenant:123:site:456:listings"
   ```

3. **Update Cache Keys**
   - File: `app/models/site.rb`
   - File: `app/models/tenant.rb`
   - File: Any other models with caching

4. **Update Invalidation**
   ```ruby
   # Before:
   Rails.cache.delete_matched("site:*")

   # After:
   Rails.cache.delete_matched("site:#{id}:*")
   ```

5. **Test**
   - Create two tenants with cached data
   - Invalidate one tenant's cache
   - Verify other tenant's cache intact

---

## Work Log

(To be filled during execution)

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
