# SQL LIKE injection in admin entries search

## Category
Periodic Review Finding - security

## Severity
high

## Description
`Admin::EntriesController#index` interpolates `params[:search]` directly into an ILIKE query:

```ruby
@entries = @entries.where(
  "title ILIKE ? OR url_canonical ILIKE ?",
  "%#{params[:search]}%", "%#{params[:search]}%"
)
```

While this uses parameterised queries (safe from SQL injection), the `%` and `_` wildcard characters in ILIKE are not escaped. A user inputting `%` would match all records; `_` matches any single character. This is a LIKE injection / wildcard abuse issue.

## Location
app/controllers/admin/entries_controller.rb:28-32

## Recommended Fix
Use `ActiveRecord::Base.sanitize_sql_like`:

```ruby
term = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"
@entries = @entries.where("title ILIKE ? OR url_canonical ILIKE ?", term, term)
```

## Impact
Minor data leakage (matching unintended records), potential performance degradation with crafted wildcard patterns.

## Acceptance Criteria
- [ ] Search parameter is sanitised with `sanitize_sql_like`
- [ ] `%` and `_` in search input are treated as literals
