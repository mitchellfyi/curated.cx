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

# PgHero 3.x uses YAML config (config/pghero.yml) instead of PgHero.config=
# Configure via environment variables or config/pghero.yml
