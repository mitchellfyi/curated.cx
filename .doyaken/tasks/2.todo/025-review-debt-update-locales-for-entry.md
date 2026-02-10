# Clean up remaining locale keys after Entry rename

## Category
Periodic Review Finding - debt

## Severity
low

## Description
The staged changes added `admin.entries.*` locale keys and updated some references from `content_item` to `entry`. However, the old `admin.listings.*` keys are still present and used by the admin form and public views. This is intentional for now since directory entries are still presented as "listings" in the UI.

Remaining cleanup:
1. The `admin.content_items.*` keys may still exist — verify and remove if unused
2. Some flash messages still reference "listing" terminology
3. Spanish locale (`es.yml`) needs the same updates as English

## Location
- config/locales/en.yml
- config/locales/es.yml

## Recommended Fix
1. Grep for any remaining `content_items` locale keys that are now unused
2. Ensure es.yml has `admin.entries.*` keys matching en.yml
3. Decide if "Listings" terminology stays in UI (it probably should for user familiarity)

## Acceptance Criteria
- [ ] No missing translation warnings in logs
- [ ] Spanish locale has all required entry keys
