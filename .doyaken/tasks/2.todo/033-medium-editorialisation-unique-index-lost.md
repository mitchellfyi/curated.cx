# Editorialisation entry_id index lost uniqueness constraint

## Category
Periodic Review Finding - debt

## Severity
medium

## Description
The old `editorialisations` table had a UNIQUE index on `content_item_id`:

```
index_editorialisations_on_content_item_id (content_item_id) UNIQUE
```

The migration creates a non-unique index on `entry_id`:

```
index_editorialisations_on_entry_id (entry_id)
```

The model comment says "Each Entry (feed) may have at most one editorialisation record (unique constraint)" and the service code checks `Editorialisation.exists?(entry_id: entry.id)` before creating new records — but this check-then-insert pattern is race-prone without a DB-level unique constraint.

## Location
- db/migrate/20260210010439_merge_content_item_and_listing_into_entries.rb (point_editorialisations_to_entries method)
- db/schema.rb:310

## Recommended Fix
Add a follow-up migration to make the index unique:

```ruby
remove_index :editorialisations, :entry_id
add_index :editorialisations, :entry_id, unique: true, name: "index_editorialisations_on_entry_id"
```

## Impact
Potential duplicate editorialisation records under concurrent load; wasted AI API calls.

## Acceptance Criteria
- [ ] Editorialisations have a unique constraint on entry_id
- [ ] Schema reflects the uniqueness requirement
