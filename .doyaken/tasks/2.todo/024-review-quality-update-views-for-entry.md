# Verify view completeness and fix remaining issues

## Category
Periodic Review Finding - quality

## Severity
medium

## Description
The staged changes updated most views from ContentItem/Listing to Entry. However, several issues remain:

1. **`listings/show.html.erb` references `@entry.ai_summaries` and `@entry.ai_tags`** — these columns don't exist on entries (tracked separately in task 028)
2. **`listings/_listing_card.html.erb` and other views use `listing.category&.category_type`** — the intent is correct but some views still reference `listing.listing_type` via the model (tracked in task 027)
3. **The `listings/` view directory name is still "listings"** — this is intentional for SEO URL compatibility but may be confusing
4. **`votes/_vote_button.html.erb`** — needs verification that the local variable name change from `content_item` to `entry` is propagated to all callers

## Location
- app/views/listings/show.html.erb
- app/views/listings/_listing_card.html.erb
- app/views/votes/_vote_button.html.erb
- app/views/tenants/show.html.erb

## Recommended Fix
1. Fix ai_summaries/ai_tags references (task 028)
2. Fix listing_type references (task 027)
3. Verify all partials receive correct local variable names
4. Add smoke test for key pages

## Acceptance Criteria
- [ ] All public pages render without errors
- [ ] No NoMethodError for missing columns
