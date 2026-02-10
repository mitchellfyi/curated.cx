# Admin entries controller: set_entry has no tenant scoping

## Category
Periodic Review Finding - security

## Severity
high

## Description
`Admin::EntriesController#set_entry` uses `Entry.includes(...).find(params[:id])` with no site/tenant scoping. This means an admin on tenant A can view, edit, update, destroy, publish, feature, etc. any entry from tenant B by passing a known ID.

The `base_scope` method returns `Entry.without_site_scope` which is intended to bypass ActsAsTenant for admin listing pages but is also used in `bulk_action` queries.

Task 021 covers the `bulk_action` case specifically, but the single-record `set_entry` is equally vulnerable and affects 14+ actions.

## Location
- app/controllers/admin/entries_controller.rb:215-217 (set_entry)
- app/controllers/admin/entries_controller.rb:213-214 (base_scope)

## Recommended Fix
Scope `set_entry` to the current site:

```ruby
def set_entry
  @entry = Entry.where(site: Current.site).includes(:category, :source, :site).find(params[:id])
end
```

Or use `base_scope.find(params[:id])` if `base_scope` is also fixed to scope to current tenant/site.

## Impact
Cross-tenant data access, modification, and deletion of entries.

## Acceptance Criteria
- [ ] `set_entry` scopes to current site/tenant
- [ ] `base_scope` includes site/tenant scoping
- [ ] Tests cover cross-tenant ID rejection
