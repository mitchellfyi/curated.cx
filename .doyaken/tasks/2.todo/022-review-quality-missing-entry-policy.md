# EntryPolicy exists but needs authorization gaps fixed

## Category
Periodic Review Finding - quality

## Severity
medium

## Description
`EntryPolicy` now exists in the staged changes. However, the `Admin::EntriesController` only calls `authorize` on 5 of its 19 actions (hide, unhide, lock_comments, unlock_comments, bulk_action). The remaining actions (show, edit, update, destroy, publish, unpublish, editorialise, enrich, feature, unfeature, extend_expiry, unschedule, publish_now) rely solely on the `AdminAccess` concern — fine for role gating, but no Pundit authorization means `verify_authorized` after-action will fail if it's enabled.

Additionally, `EntryPolicy#checkout?` checks `record.respond_to?(:submitted_by_id)` but Entry doesn't have a `submitted_by_id` column.

## Location
- app/controllers/admin/entries_controller.rb
- app/policies/entry_policy.rb:55

## Recommended Fix
1. Add `authorize @entry` or `authorize Entry` to all admin entry actions
2. Remove `submitted_by_id` reference from `EntryPolicy#checkout?` or add the relation

## Acceptance Criteria
- [ ] All admin entry actions call `authorize`
- [ ] `EntryPolicy#checkout?` references valid columns
- [ ] Tests cover authorization
