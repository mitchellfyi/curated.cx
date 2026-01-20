# Safe Database Migrations for Curated.www

## Overview

This document provides comprehensive guidance for creating safe database migrations in our multi-tenant Rails application. All migrations must be safe for production deployment without downtime.

## Core Principles

1. **Zero Downtime**: All migrations must run without blocking the application
2. **Multi-tenant Safe**: Consider tenant isolation in all schema changes
3. **Reversible**: All migrations must be safely rollbackable
4. **Tested**: Test on production-sized datasets before deployment
5. **Performance Conscious**: Consider impact on large tables

## Strong Migrations Integration

We use the [Strong Migrations](https://github.com/ankane/strong_migrations) gem to catch dangerous migration patterns before they reach production.

### Configuration

```ruby
# config/initializers/strong_migrations.rb
StrongMigrations.configure do |config|
  config.auto_analyze = true
  config.lock_timeout = 10.seconds
  config.statement_timeout = 1.hour
end
```

## Safe Migration Patterns

### 1. Adding Columns

#### ✅ SAFE: Add column without default

```ruby
class AddStatusToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :status, :string
  end
end

# Then in a separate migration or data migration:
class BackfillListingStatus < ActiveRecord::Migration[8.0]
  def up
    # Backfill in batches to avoid long locks
    Listing.in_batches(of: 1000) do |batch|
      batch.update_all(status: 'draft')
    end
  end

  def down
    # No need to remove data, column removal handles this
  end
end
```

#### ❌ DANGEROUS: Add column with default value

```ruby
# This can lock the entire table during backfill
class AddStatusToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :status, :string, default: 'draft'
  end
end
```

### 2. Adding Indexes

#### ✅ SAFE: Add index concurrently

```ruby
class AddIndexToListingsStatus < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :listings, :status, algorithm: :concurrently
  end
end
```

#### ❌ DANGEROUS: Add index without concurrently

```ruby
# This can lock the table for the duration of index creation
class AddIndexToListingsStatus < ActiveRecord::Migration[8.0]
  def change
    add_index :listings, :status  # No algorithm specified
  end
end
```

### 3. Multi-tenant Table Creation

#### ✅ SAFE: New table with proper tenant isolation

```ruby
class CreateSources < ActiveRecord::Migration[8.0]
  def change
    create_table :sources do |t|
      t.references :tenant, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :kind, null: false
      t.jsonb :config, null: false, default: {}
      t.jsonb :schedule, null: false, default: {}
      t.datetime :last_run_at
      t.string :last_status

      t.timestamps
    end

    # Ensure tenant isolation at database level
    add_index :sources, [:tenant_id, :name], unique: true
    add_index :sources, :kind
    add_index :sources, :last_run_at
  end
end
```

### 4. Removing Columns (Multi-step Process)

#### Step 1: Stop using the column in code

```ruby
# Deploy code that no longer references the column
# Wait for deployment to complete
```

#### Step 2: Remove column in migration

```ruby
class RemoveDeprecatedColumnFromListings < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :listings, :deprecated_field, :string }
  end
end
```

### 5. Changing Column Types

#### ✅ SAFE: Multi-step approach

```ruby
# Step 1: Add new column
class AddNewContentTypeToListings < ActiveRecord::Migration[8.0]
  def change
    add_column :listings, :content_type_new, :integer
  end
end

# Step 2: Backfill data
class BackfillContentTypeNew < ActiveRecord::Migration[8.0]
  def up
    Listing.in_batches(of: 1000) do |batch|
      batch.update_all(
        "content_type_new = CASE
           WHEN content_type = 'article' THEN 1
           WHEN content_type = 'video' THEN 2
           ELSE 0
         END"
      )
    end
  end

  def down
    # Reverse mapping if needed
  end
end

# Step 3: Update code to use new column
# Step 4: Remove old column
class RemoveOldContentTypeFromListings < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :listings, :content_type, :string }
  end
end

# Step 5: Rename new column
class RenameContentTypeNewToContentType < ActiveRecord::Migration[8.0]
  def change
    safety_assured { rename_column :listings, :content_type_new, :content_type }
  end
end
```

### 6. Adding Foreign Key Constraints

#### ✅ SAFE: Add foreign key to existing data

```ruby
class AddForeignKeyToListings < ActiveRecord::Migration[8.0]
  def change
    # First, clean up any orphaned records
    # This should be done in a data migration first
    add_foreign_key :listings, :categories, validate: false
  end
end

# Then validate in a separate migration
class ValidateForeignKeyOnListings < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :listings, :categories
  end
end
```

## Multi-tenant Specific Considerations

### 1. Tenant Isolation

Every tenant-scoped table MUST include:

```ruby
t.references :tenant, null: false, foreign_key: true, index: true
```

### 2. Unique Constraints with Tenant Scope

```ruby
# Ensure uniqueness per tenant, not globally
add_index :listings, [:tenant_id, :url_canonical], unique: true
```

### 3. Data Seeding for All Tenants

```ruby
class AddDefaultCategoriesToAllTenants < ActiveRecord::Migration[8.0]
  def up
    Tenant.find_each do |tenant|
      ActsAsTenant.with_tenant(tenant) do
        Category.find_or_create_by!(key: 'news', name: 'News')
      end
    end
  end

  def down
    # Define rollback strategy
  end
end
```

## Performance Considerations

### 1. Batch Processing

Always process large datasets in batches:

```ruby
def up
  Listing.in_batches(of: 1000) do |batch|
    batch.update_all(status: 'published')
    sleep 0.1  # Be gentle on the database
  end
end
```

### 2. Lock Timeouts

Configure appropriate timeouts:

```ruby
class LongRunningMigration < ActiveRecord::Migration[8.0]
  def up
    execute "SET lock_timeout = '30s'"
    execute "SET statement_timeout = '1h'"

    # Your migration code here
  end
end
```

### 3. Monitor Progress

For long-running migrations:

```ruby
def up
  total = Listing.count
  processed = 0

  Listing.in_batches(of: 1000) do |batch|
    batch.update_all(updated_field: new_value)
    processed += batch.size
    puts "Progress: #{processed}/#{total} (#{(processed.to_f/total * 100).round(1)}%)"
  end
end
```

## Rollback Safety

### 1. Reversible Migrations

Use `change` method when possible:

```ruby
class AddIndexToListings < ActiveRecord::Migration[8.0]
  def change
    add_index :listings, :status  # Automatically reversible
  end
end
```

### 2. Irreversible Operations

Use explicit `up` and `down` methods:

```ruby
class ComplexDataMigration < ActiveRecord::Migration[8.0]
  def up
    # Complex data transformation
    execute <<~SQL
      UPDATE listings
      SET processed_data = complex_function(raw_data)
      WHERE processed_data IS NULL
    SQL
  end

  def down
    # Clear processed data
    execute "UPDATE listings SET processed_data = NULL"
  end
end
```

## Testing Migrations

### 1. Local Testing

```bash
# Test migration up
bundle exec rails db:migrate

# Test rollback
bundle exec rails db:rollback

# Test with production-like data volume
# (Create test data first)
```

### 2. Production Simulation

```ruby
# Create a staging environment with production data volume
# Test migration timing and impact
```

## Common Pitfalls and Solutions

### 1. Adding NOT NULL Columns

❌ **Wrong**:
```ruby
add_column :listings, :required_field, :string, null: false
```

✅ **Right**:
```ruby
# Step 1: Add nullable column
add_column :listings, :required_field, :string

# Step 2: Backfill data
Listing.update_all(required_field: 'default_value')

# Step 3: Add NOT NULL constraint
change_column_null :listings, :required_field, false
```

### 2. Renaming Tables/Columns

❌ **Wrong**: Direct rename in one migration

✅ **Right**: Multi-deployment process
1. Add new table/column
2. Dual-write to both
3. Backfill old → new
4. Switch reads to new
5. Remove old table/column

### 3. Large Table Modifications

For tables with > 10k rows:
- Use `algorithm: :concurrently` for indexes
- Process in batches with delays
- Consider maintenance windows for major changes
- Monitor replication lag if using read replicas

## Migration Checklist

Before creating a migration:

- [ ] Will this migration run safely on a production database?
- [ ] Does it respect multi-tenant isolation?
- [ ] Are there any long-running lock operations?
- [ ] Is the migration reversible?
- [ ] Have I tested it with production-like data volumes?
- [ ] Does it include proper error handling?
- [ ] Are foreign key constraints properly named?
- [ ] Do new tables include all necessary indexes?

## Emergency Procedures

### Rolling Back a Migration

```bash
# Rollback last migration
bundle exec rails db:rollback

# Rollback specific migration
bundle exec rails db:migrate:down VERSION=20231201120000

# Rollback multiple migrations
bundle exec rails db:rollback STEP=3
```

### Fixing a Stuck Migration

```sql
-- Check for blocking queries
SELECT * FROM pg_stat_activity WHERE state = 'active';

-- Kill blocking queries (if safe)
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
WHERE state = 'active' AND query LIKE '%your_table%';

-- Check lock status
SELECT * FROM pg_locks WHERE relation::regclass::text = 'your_table';
```

## Resources

- [Strong Migrations Gem](https://github.com/ankane/strong_migrations)
- [Rails Migration Guide](https://guides.rubyonrails.org/active_record_migrations.html)
- [PostgreSQL Concurrent Operations](https://www.postgresql.org/docs/current/sql-createindex.html#SQL-CREATEINDEX-CONCURRENTLY)
- [Multi-tenant Database Patterns](https://docs.microsoft.com/en-us/azure/sql-database/saas-tenancy-app-design-patterns)

## Script Usage

Run the migration safety checker:

```bash
./script/dev/migrations
```

This will:
- Check pending migrations
- Analyze recent migrations for safety issues
- Validate multi-tenant compliance
- Check database schema integrity
