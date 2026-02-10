# Bookmarks view: unreachable branch for directory entries

## Category
Periodic Review Finding - quality

## Severity
medium

## Description
In `app/views/bookmarks/index.html.erb`, the bookmark display logic was updated from:

```erb
<% if bookmark.bookmarkable.is_a?(ContentItem) %>
  ...
<% elsif bookmark.bookmarkable.is_a?(Listing) %>
```

To:

```erb
<% if bookmark.bookmarkable.is_a?(Entry) %>
  ...
<% elsif bookmark.bookmarkable.is_a?(Entry) && bookmark.bookmarkable.directory? %>
```

Since both `ContentItem` and `Listing` are now `Entry`, the first branch catches ALL entry bookmarks (feed and directory). The `elsif` branch is unreachable — directory entries will always render with the feed/content template instead of the listing template.

## Location
app/views/bookmarks/index.html.erb:16,34

## Recommended Fix
```erb
<% if bookmark.bookmarkable.is_a?(Entry) && bookmark.bookmarkable.feed? %>
  ... feed template ...
<% elsif bookmark.bookmarkable.is_a?(Entry) && bookmark.bookmarkable.directory? %>
  ... directory template ...
```

## Impact
Directory bookmarks display with wrong template (missing category badge, company info, etc.)

## Acceptance Criteria
- [ ] Feed bookmarks render with feed template
- [ ] Directory bookmarks render with directory template
