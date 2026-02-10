# BLOCKER: listing_type column missing from entries table

## Category
Periodic Review Finding - quality

## Severity
blocker

## Description
The `Entry` model references `listing_type` in two methods:
- `job?` (line 315): `directory? && listing_type.to_i == 1`
- `listing_type_key` (line 318): `LISTING_TYPE_KEYS[listing_type.to_i] || "tool"`

The admin form (`_form.html.erb:24`) renders a `listing_type` select field.
The factory traits `:tool`, `:job`, `:service` set `listing_type`.

**But the `entries` table has no `listing_type` column.** The migration never created it. The old `listings` table had it, but it was not carried over.

This will cause `ActiveRecord::StatementInvalid` / `NoMethodError` whenever:
- An admin creates/edits a directory entry
- `Entry#job?` or `listing_type_key` is called (used in views and decorators)

## Location
- app/models/entry.rb:315-319
- app/views/admin/entries/_form.html.erb:24-25
- db/migrate/20260210010439_merge_content_item_and_listing_into_entries.rb (missing column)
- spec/factories/entries.rb (:tool, :job, :service traits)

## Recommended Fix
Either:
1. Add `listing_type` integer column to entries table in a follow-up migration
2. OR remove `listing_type` entirely and use `category.category_type` instead (some views already do this)

Option 2 is cleaner — the `CheckoutsController` and public views already use `category.category_type`.

## Impact
Runtime crash on admin entry forms and any view rendering listing type badges for directory entries.

## Acceptance Criteria
- [ ] `Entry#job?` and `listing_type_key` work without errors
- [ ] Admin entry form works for directory entries
- [ ] Factory traits build without errors
