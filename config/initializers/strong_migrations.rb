# frozen_string_literal: true

# Mark existing migrations as safe - these were created before strong_migrations
StrongMigrations.start_after = 20250927152744

# Set timeouts for migrations
# Adjust these based on your database size and requirements
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

# Analyze tables after indexes are added
# Helps maintain good query performance
StrongMigrations.auto_analyze = true

# Set the version of the production database
# Update this to match your production PostgreSQL version
StrongMigrations.target_version = 15

# Enable safe by default for common operations
StrongMigrations.safe_by_default = true

# Remove invalid indexes when rerunning migrations
# Helpful for development and testing
StrongMigrations.remove_invalid_indexes = true

# Custom checks for tenant-based architecture
StrongMigrations.add_check do |method, args|
  # Warn about operations on large tables that might cause downtime
  large_tables = %w[users tenants roles]

  if [ :add_column, :change_column, :remove_column ].include?(method)
    table_name = args[0].to_s
    if large_tables.include?(table_name)
      # For large tables, suggest using safer migration patterns
      case method
      when :add_column
        if args.length > 2 && args[2]&.key?(:default) && args[2][:default]
          stop! <<~MSG
            Adding a column with a default value to #{table_name} can cause downtime.

            Instead, add the column without a default value:
              add_column :#{table_name}, :#{args[1]}, :#{args[2]&.fetch(:type, 'string')}

            Then backfill in batches:
              #{table_name.classify}.in_batches.update_all(#{args[1]}: #{args[2][:default].inspect})

            Finally, add the default:
              change_column_default :#{table_name}, :#{args[1]}, #{args[2][:default].inspect}
          MSG
        end
      when :change_column
        stop! <<~MSG
          Changing column type on #{table_name} can cause downtime.

          Consider a multi-step approach:
          1. Add the new column
          2. Migrate data in batches#{'  '}
          3. Update application code to use new column
          4. Remove old column in a later migration
        MSG
      when :remove_column
        stop! <<~MSG
          Removing a column from #{table_name} can cause errors.

          First deploy application code that doesn't use the column,
          then remove it in a later migration.
        MSG
      end
    end
  end

  # Ensure tenant_id is properly indexed for multi-tenant tables
  if method == :create_table && args[1]&.key?(:tenant)
    puts "⚠️  Remember to add an index on tenant_id for #{args[0]} table for optimal multi-tenant performance"
  end
end

# Development-specific configuration
if Rails.env.development?
  # Be more lenient in development
  StrongMigrations.lock_timeout = 30.seconds
  StrongMigrations.statement_timeout = 10.minutes
end

# Production-specific configuration
if Rails.env.production?
  # Be extra cautious in production
  StrongMigrations.lock_timeout = 5.seconds
  StrongMigrations.statement_timeout = 30.minutes

  # Enable additional safety checks
  StrongMigrations.alphabetize_schema = true
end
