# frozen_string_literal: true

# Override existing Rails database tasks to include connection termination
namespace :db do
  # Override the existing db:drop task (only if it exists)
  Rake::Task["db:drop"].clear if Rake::Task.task_defined?("db:drop")

  desc "Drop the database"
  task drop: :environment do
    # Force terminate all connections before dropping
    force_terminate_connections

    # Close all active connections
    ActiveRecord::Base.connection_pool.disconnect!

    # Wait for connections to close
    sleep(2)

    # Drop the database (original Rails logic)
    ActiveRecord::Tasks::DatabaseTasks.drop_current
  end

  # Override the existing db:reset task (only if it exists)
  Rake::Task["db:reset"].clear if Rake::Task.task_defined?("db:reset")

  desc "Drop and setup the database from scratch"
  task reset: :environment do
    # Force terminate all connections before dropping
    force_terminate_connections

    # Close all active connections
    ActiveRecord::Base.connection_pool.disconnect!

    # Wait for connections to close
    sleep(2)

    # Drop the database
    Rake::Task["db:drop"].invoke

    # Setup the database (create, migrate, seed)
    Rake::Task["db:setup"].invoke
  end

  # Safe database tasks with connection termination
  desc "Show database connection status"
  task connections: :environment do
    config = ActiveRecord::Base.connection_db_config
    puts "Database: #{config.database}"
    puts "Pool size: #{ActiveRecord::Base.connection_pool.size}"
    puts "Active connections: #{ActiveRecord::Base.connection_pool.connections.count}"
  end

  desc "Close all database connections"
  task close_connections: :environment do
    force_terminate_connections
    ActiveRecord::Base.connection_pool.disconnect!
    puts "All connections closed"
  end

  desc "Safely drop database with connection termination"
  task drop_safe: :environment do
    force_terminate_connections
    ActiveRecord::Base.connection_pool.disconnect!
    sleep(1)
    ActiveRecord::Tasks::DatabaseTasks.drop_current
  end

  desc "Safely create database"
  task create_safe: :environment do
    ActiveRecord::Tasks::DatabaseTasks.create_current
  end

  desc "Safely migrate database"
  task migrate_safe: :environment do
    ActiveRecord::Tasks::DatabaseTasks.migrate
  end

  desc "Safely setup database (create, migrate, seed)"
  task setup_safe: :environment do
    Rake::Task["db:create_safe"].invoke
    Rake::Task["db:migrate_safe"].invoke
    Rake::Task["db:seed"].invoke if Rake::Task.task_defined?("db:seed")
  end

  desc "Safely reset database with connection termination"
  task reset_safe: :environment do
    force_terminate_connections
    ActiveRecord::Base.connection_pool.disconnect!
    sleep(1)
    Rake::Task["db:drop_safe"].invoke
    Rake::Task["db:setup_safe"].invoke
  end
end

# Helper method to force terminate all connections to the database
def force_terminate_connections
  return unless ActiveRecord::Base.connected?

  begin
    # Get database configuration
    config = ActiveRecord::Base.connection_db_config
    database_name = config.database

    # Connect to postgres database to terminate connections
    postgres_config = config.dup
    postgres_config.database = "postgres"

    # Create a temporary connection to postgres
    postgres_connection = ActiveRecord::Base.postgresql_connection(postgres_config)

    # Terminate all connections to our database
    postgres_connection.execute(<<~SQL)
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = '#{database_name}'
      AND pid <> pg_backend_pid();
    SQL

    postgres_connection.disconnect!

  rescue => e
    # Silently continue - the regular disconnect might work
  end
end
