# Verify job rename completeness (ContentItem → Entry)

## Category
Periodic Review Finding - quality

## Severity
low

## Description
The staged changes have already renamed all job files and references from ContentItem/Listing to Entry. The key renames are:
- `EnrichContentItemJob` → `EnrichEntryJob`
- `EditorialiseContentItemJob` → `EditorialiseEntryJob` (with `EditorialisationJob` alias)
- `UpsertListingsJob` → `UpsertEntriesJob`
- All other jobs updated to reference `Entry`

**Remaining concern**: The physical files still have old names (`enrich_content_item_job.rb`, `editorialise_content_item_job.rb`, `upsert_listings_job.rb`). The class names inside were changed but filenames were not. Rails autoloading should still work because the old filenames contain aliases/renamed classes, but it's confusing.

Also need to verify that the SerpApi ingestion jobs (Amazon, Google Scholar, Shopping, Reddit, YouTube, Jobs) were fully converted — they weren't shown in the diff review.

## Location
- app/jobs/enrich_content_item_job.rb (class is now EnrichEntryJob)
- app/jobs/editorialise_content_item_job.rb (class is now EditorialiseEntryJob)
- app/jobs/upsert_listings_job.rb (class is now UpsertEntriesJob)

## Recommended Fix
1. Rename job files to match class names
2. Verify all SerpApi ingestion jobs reference Entry
3. Run full test suite to confirm

## Impact
Low — code works but filenames are misleading

## Acceptance Criteria
- [ ] Job filenames match class names
- [ ] All SerpApi jobs reference Entry
- [ ] Tests pass
