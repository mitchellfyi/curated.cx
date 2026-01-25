# Cache Key Conventions

## Overview

This document defines the cache key naming conventions and scoped invalidation patterns for the Curated.www multi-tenant application. Proper cache key design is critical to avoid cross-tenant cache pollution and ensure efficient cache invalidation.

## Core Principle: Scope by Resource ID

In a multi-tenant application, cache invalidation must be scoped to the specific tenant/site being modified. Broad cache clearing (e.g., `delete_matched("site:*")`) invalidates caches for ALL tenants, causing unnecessary cache misses and potential performance degradation.

## Cache Key Naming Pattern

```
<resource>:<identifier>:<sub_resource>[:additional_qualifiers]

Examples:
- tenant:hostname:example.com    # Hostname lookup (naturally unique)
- tenant:root                    # Singleton root tenant (no scoping needed)
- tenant:42:settings             # Tenant-scoped data
- site:hostname:shop.example.com # Site by hostname (naturally unique)
- site:17:metadata               # Site-scoped data
- listings:recent:17:10          # Site 17, limit 10
- listings:count_by_category:17  # Site 17 category counts
```

## Invalidation Patterns

### Scoped Invalidation (Preferred)

When clearing cache for a specific resource, scope the deletion pattern:

```ruby
# GOOD: Clear only this tenant's scoped cache entries
Rails.cache.delete_matched("tenant:#{id}:*")

# GOOD: Clear only this site's scoped cache entries
Rails.cache.delete_matched("site:#{id}:*")

# GOOD: Clear only this site's listing cache
Rails.cache.delete_matched("listings:recent:#{site_id}:*")
```

### Hostname-Based Keys (Naturally Unique)

Hostname-based cache keys are naturally unique and should be deleted explicitly:

```ruby
# Delete specific hostname cache entry
Rails.cache.delete("tenant:hostname:#{hostname}")
Rails.cache.delete("site:hostname:#{hostname}")
```

### Global Invalidation (Use Sparingly)

For administrative operations that require clearing all caches of a type:

```ruby
# ONLY for explicit "clear all" operations
# Method should be named clearly: clear_all_tenant_caches!
Rails.cache.delete_matched("tenant:*")
```

## Model Examples

### Tenant Model

```ruby
class Tenant < ApplicationRecord
  # Clear only this tenant's cache
  def clear_tenant_cache
    # Explicit key deletions for hostname lookups
    Rails.cache.delete("tenant:hostname:#{hostname}")
    Rails.cache.delete("tenant:root") if root?

    # Scoped pattern deletion for tenant-specific cached data
    Rails.cache.delete_matched("tenant:#{id}:*")
  end

  # Administrative: Clear ALL tenant caches (use sparingly)
  def self.clear_all_tenant_caches!
    Rails.cache.delete_matched("tenant:*")
  end
end
```

### Site Model

```ruby
class Site < ApplicationRecord
  def clear_site_cache
    # Delete hostname-based keys explicitly
    domains.each do |domain|
      Rails.cache.delete("site:hostname:#{domain.hostname}")
    end

    # Scoped pattern deletion for site-specific cached data
    Rails.cache.delete_matched("site:#{id}:*")
  end
end
```

### Listing Model (Reference Implementation)

The Listing model demonstrates proper scoped cache patterns:

```ruby
class Listing < ApplicationRecord
  # Cache keys include site_id for proper scoping
  def self.cached_recent(site_id:, limit:)
    Rails.cache.fetch("listings:recent:#{site_id}:#{limit}") do
      # ... query
    end
  end

  # Invalidation scoped to specific site
  def clear_listing_caches
    Rails.cache.delete_matched("listings:recent:#{site_id}:*")
    Rails.cache.delete("listings:count_by_category:#{site_id}")
  end
end
```

## Anti-Patterns to Avoid

### Overly Broad Invalidation

```ruby
# BAD: Clears ALL site caches across ALL tenants
Rails.cache.delete_matched("site:*")

# GOOD: Clears only this site's cache
Rails.cache.delete_matched("site:#{id}:*")
```

### Missing Resource ID in Keys

```ruby
# BAD: No site scoping, will collide across sites
Rails.cache.fetch("listings:recent:#{limit}") { ... }

# GOOD: Scoped by site_id
Rails.cache.fetch("listings:recent:#{site_id}:#{limit}") { ... }
```

### Implicit Assumptions About Uniqueness

```ruby
# BAD: Assumes category names are unique across all sites
Rails.cache.fetch("category:#{category.name}") { ... }

# GOOD: Explicit site scoping
Rails.cache.fetch("category:#{site_id}:#{category.name}") { ... }
```

## Cache Store Considerations

### Redis

- `delete_matched` uses SCAN internally (safe for production)
- Pattern matching is efficient but still O(n) on key count
- Consider using explicit key tracking for very high-traffic scenarios

### Memcached

- `delete_matched` is NOT supported
- Use explicit key lists or versioned cache keys instead
- Consider callback-based invalidation with explicit deletes

## Testing Cache Isolation

When writing tests for cache functionality, verify that:

1. Updating one tenant's data does not clear another tenant's cache
2. Scoped invalidation patterns match the expected resource ID
3. Hostname-based keys are deleted explicitly, not via pattern

Example test pattern:

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

## Related Documentation

- [Rails Caching Guide](https://guides.rubyonrails.org/caching_with_rails.html)
- [QUALITY_ENFORCEMENT.md](QUALITY_ENFORCEMENT.md) - Quality gate 9 covers performance and caching
- [ANTI_PATTERN_PREVENTION.md](ANTI_PATTERN_PREVENTION.md) - General anti-patterns to avoid
