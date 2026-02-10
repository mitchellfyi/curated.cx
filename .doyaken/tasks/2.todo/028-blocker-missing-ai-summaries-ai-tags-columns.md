# BLOCKER: ai_summaries and ai_tags columns missing from entries table

## Category
Periodic Review Finding - quality

## Severity
blocker

## Description
The public listing show view (`app/views/listings/show.html.erb`) references `@entry.ai_summaries` (18 occurrences) and `@entry.ai_tags` to display AI summaries and keyword tags.

**Neither `ai_summaries` nor `ai_tags` columns exist on the `entries` table.** The old `listings` table had these as JSONB columns, but they were not included in the migration to `entries`.

This will cause `NoMethodError` when viewing any directory entry that previously had AI summaries.

## Location
- app/views/listings/show.html.erb (lines referencing ai_summaries, ai_tags)
- db/schema.rb (entries table — columns missing)

## Recommended Fix
Either:
1. Add `ai_summaries jsonb default: {}` and `ai_tags jsonb default: {}` columns to entries via migration
2. OR remove the view sections that reference these columns (if the feature is being deprecated)
3. OR map these to the existing `ai_summary` (text) and `ai_suggested_tags` (jsonb) columns that DO exist on entries

Option 3 is likely correct — the entry model already has `ai_summary` and `ai_suggested_tags`, which serve a similar purpose. The view just needs updating to use the correct column names.

## Impact
Runtime crash (NoMethodError) when viewing any directory entry in the public show page.

## Acceptance Criteria
- [ ] Public listing show page renders without errors
- [ ] AI summary content displays correctly if present
