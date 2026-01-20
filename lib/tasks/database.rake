# frozen_string_literal: true

# Override existing Rails database tasks to include connection termination
namespace :db do
  # Override the existing db:drop task
  Rake::Task['db:drop'].clear

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

  # Override the existing db:reset task
  Rake::Task['db:reset'].clear

  desc "Drop and setup the database from scratch"
  task reset: :environment do
    # Force terminate all connections before dropping
    force_terminate_connections

    # Close all active connections
    ActiveRecord::Base.connection_pool.disconnect!

    # Wait for connections to close
    sleep(2)

    # Drop the database
    Rake::Task['db:drop'].invoke

    # Setup the database (create, migrate, seed)
    Rake::Task['db:setup'].invoke
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
    postgres_config.database = 'postgres'

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
