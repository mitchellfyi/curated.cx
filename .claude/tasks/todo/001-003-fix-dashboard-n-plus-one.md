# Task: Fix N+1 Queries in Admin Dashboard

## Metadata

| Field | Value |
|-------|-------|
| ID | `001-003-fix-dashboard-n-plus-one` |
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

The Admin Dashboard controller has multiple query efficiency issues:

```ruby
# app/controllers/admin/dashboard_controller.rb

# Problem 1: Duplicate count queries
@stats = {
  total_listings: Current.tenant.listings.published.count,
  published_listings: Current.tenant.listings.published.count,  # DUPLICATE!
  listings_today: Current.tenant.listings.published.where(created_at: ...).count
}

# Problem 2: Array operations instead of SQL
@categories = categories_service.all_categories
@categories = (@categories + Current.tenant.categories.to_a).uniq
@categories = @categories.select { |cat| cat.tenant_id == Current.tenant.id }

# Problem 3: Missing eager loading
# Categories loaded without includes, causing N+1 in views
```

**Impact**: Dashboard makes 5+ database queries when 1-2 would suffice.

---

## Acceptance Criteria

- [ ] Remove duplicate `published.count` query
- [ ] Replace Ruby array filtering with SQL scope
- [ ] Add eager loading for associations used in views
- [ ] Consolidate stats into single query with `select`
- [ ] Add query count test (bullet gem or manual)
- [ ] Dashboard page loads with ≤3 queries
- [ ] All existing functionality preserved
- [ ] Quality gates pass

---

## Plan

1. **Audit Current Queries**
   - Enable query logging in development
   - Count queries on dashboard load
   - Document each query and its purpose

2. **Consolidate Stats Query**
   ```ruby
   # Single query with conditional counts:
   @stats = Listing.where(tenant: Current.tenant)
     .select(
       'COUNT(*) FILTER (WHERE status = ?) as total_published',
       'COUNT(*) FILTER (WHERE created_at >= ?) as today_count'
     ).take
   ```

3. **Fix Category Loading**
   ```ruby
   @categories = Category.where(tenant: Current.tenant)
     .includes(:listings)
     .order(:name)
   ```

4. **Add Eager Loading**
   - Identify associations accessed in dashboard views
   - Add `.includes()` for all

5. **Test**
   - Add spec that asserts query count
   - Consider adding Bullet gem for CI

---

## Work Log

(To be filled during execution)

---

## Notes

Rails patterns for query optimization:
- `select()` with SQL functions for aggregates
- `includes()` for eager loading
- `pluck()` when you only need specific columns
- Consider counter_cache for frequently counted associations

PostgreSQL-specific:
- `COUNT(*) FILTER (WHERE condition)` for conditional aggregates
- Single query instead of multiple count queries

---

## Links

- File: `app/controllers/admin/dashboard_controller.rb`
- File: `app/services/admin/listings_service.rb`
- Gem: https://github.com/flyerhzm/bullet (N+1 detection)
