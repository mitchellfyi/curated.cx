# Add Content Analytics Dashboard for Tenants

## Summary
Build an analytics dashboard that tenant admins can use to see performance metrics for their content and listings.

## Why
Tenant admins currently have limited visibility into how their content is performing. An analytics dashboard would:
- Help publishers understand what content resonates
- Enable data-driven content strategy
- Increase platform stickiness

## Acceptance Criteria
- [ ] Add new dashboard route under admin namespace
- [ ] Show top performing articles by views/engagement
- [ ] Display listing metrics (views, clicks, conversions)
- [ ] Include time-based charts (last 7d, 30d, 90d)
- [ ] Ensure multi-tenant isolation (each tenant sees only their data)

## Technical Notes
- Leverage existing PGHero/monitoring infrastructure
- Use Chartkick or similar for visualizations
- May need to add event tracking if not already present
- Consider caching aggregated metrics for performance

## Priority
Medium - Strong tenant value, moderate complexity
