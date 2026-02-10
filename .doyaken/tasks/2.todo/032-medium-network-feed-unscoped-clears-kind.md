# NetworkFeedService: unscoped clears feed_items/directory_items scope

## Category
Periodic Review Finding - quality

## Severity
medium

## Description
In `app/services/network_feed_service.rb`, the network stats query chains `.unscoped` after `.feed_items`/`.directory_items`:

```ruby
content_count: Entry.feed_items.unscoped.where(site_id: site_ids)...
listing_count: Entry.directory_items.unscoped.where(site_id: site_ids)...
```

`.unscoped` removes ALL prior scopes, including the `where(entry_kind: "feed")` from `feed_items`. This means both counts will include ALL entries regardless of kind, producing incorrect numbers.

Similarly, `recent_publishable_items` has:
```ruby
scope = model_class.unscoped
scope = scope.feed_items if model_class == Entry
```
This is correct because `feed_items` is applied after `unscoped`.

## Location
app/services/network_feed_service.rb:96-97

## Recommended Fix
```ruby
content_count: Entry.unscoped.where(entry_kind: "feed", site_id: site_ids)...
listing_count: Entry.unscoped.where(entry_kind: "directory", site_id: site_ids)...
```

## Impact
Incorrect network stats — both feed and directory counts will show total entry count.

## Acceptance Criteria
- [ ] Network stats correctly separate feed vs directory counts
- [ ] `unscoped` does not clear entry_kind filtering
