# frozen_string_literal: true

# PgHero configuration for PostgreSQL performance monitoring
# Dashboard available at /admin/pghero (super admin only)
#
# For query stats, ensure pg_stat_statements is enabled in PostgreSQL:
#   shared_preload_libraries = 'pg_stat_statements'
#   pg_stat_statements.track = all
#
# Then in psql:
#   CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

PgHero.config = {
  databases: {
    primary: {
      url: ENV["DATABASE_URL"]
    }
  },

  # Query stats settings
  # Set to true once pg_stat_statements is enabled
  query_stats_enabled: ENV.fetch("PGHERO_QUERY_STATS_ENABLED", "false") == "true",

  # Minimum query time to track (in milliseconds)
  slow_query_ms: ENV.fetch("PGHERO_SLOW_QUERY_MS", 100).to_i,

  # Long-running query threshold (in seconds)
  long_running_query_sec: ENV.fetch("PGHERO_LONG_RUNNING_QUERY_SEC", 60).to_i,

  # Number of query stats to show
  query_stats_top_queries: ENV.fetch("PGHERO_TOP_QUERIES", 100).to_i
}
