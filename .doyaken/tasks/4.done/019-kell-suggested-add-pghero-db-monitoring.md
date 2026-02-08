# Add PgHero Database Performance Monitoring

**Priority:** Low
**Type:** Enhancement
**Suggested by:** Kell (automated)
**Date:** 2026-02-08

## Summary

Add PgHero for PostgreSQL database performance visibility in the admin area. This provides insights into slow queries, index usage, table sizes, and connection health - valuable for a multi-tenant platform.

## Why

- Multi-tenant apps need visibility into database performance
- Identify slow queries before they become problems
- Track index usage and missing indexes
- Monitor table bloat and space usage
- No external service required - runs in-app

## Implementation

1. Add `pghero` gem to Gemfile
2. Mount PgHero engine in routes (admin namespace)
3. Add authentication (admin-only access)
4. Configure query stats collection
5. Add link to admin sidebar

## Files to Modify

- `Gemfile` - add gem
- `config/routes.rb` - mount engine
- `config/initializers/pghero.rb` - configuration
- `app/views/admin/shared/_sidebar.html.erb` - add link (if exists)

## Acceptance Criteria

- [ ] PgHero accessible at `/admin/pghero`
- [ ] Only super admins can access
- [ ] Query stats enabled for slow query tracking
- [ ] Tests pass
- [ ] Documentation in README

## References

- https://github.com/ankane/pghero
