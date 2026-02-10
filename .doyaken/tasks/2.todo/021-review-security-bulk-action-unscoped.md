# Scope bulk_action in Admin::EntriesController

## Category
Periodic Review Finding - security

## Severity
high

## Description
`Admin::EntriesController#bulk_action` performs `Entry.where(id: ids)` without any site/tenant scoping. A malicious or confused admin could pass entry IDs belonging to a different tenant, allowing cross-tenant data modification (publish, unpublish, editorialise, enrich, delete).

Additionally, the `bulk_action` method does not call Pundit `authorize` on the entries being acted upon, bypassing fine-grained authorization.

## Location
app/controllers/admin/entries_controller.rb:170-196

## Recommended Fix
1. Scope the query: `entries = base_scope.where(id: ids)` or `Entry.where(id: ids, site: Current.site)`
2. Add Pundit authorization: `authorize Entry, :bulk_action?` (or individual checks per action type)
3. Add the corresponding `bulk_action?` method to EntryPolicy

## Impact
Cross-tenant data modification; unauthorized bulk operations on entries

## Acceptance Criteria
- [ ] `bulk_action` scopes entries to current site/tenant
- [ ] Pundit authorization is enforced for bulk operations
- [ ] Test covers cross-tenant ID rejection
