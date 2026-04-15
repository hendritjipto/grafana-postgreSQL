#!/usr/bin/env bash
set -e

# Creates the Grafana Alloy monitoring user with privileges required
# for Database Observability across both 'grafana' and 'bank' databases.
# Reads DB_O11Y_PASSWORD from the environment.

# --- Global user + role grants (run once, not per-database) ---
psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname   "$POSTGRES_DB" <<-EOSQL

    CREATE USER "db-o11y" WITH PASSWORD '${DB_O11Y_PASSWORD}';

    GRANT pg_monitor        TO "db-o11y";
    GRANT pg_read_all_stats TO "db-o11y";
    GRANT pg_read_all_data  TO "db-o11y";

    -- Suppress tracking of monitoring queries in pg_stat_statements
    ALTER ROLE "db-o11y" SET pg_stat_statements.track = 'none';

    -- Schema-level grants in the grafana database
    GRANT USAGE  ON SCHEMA public TO "db-o11y";
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO "db-o11y";

EOSQL

# --- Schema-level grants in the bank database ---
psql -v ON_ERROR_STOP=1 \
     --username "$POSTGRES_USER" \
     --dbname   "bank" <<-EOSQL

    GRANT USAGE  ON SCHEMA public TO "db-o11y";
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO "db-o11y";

EOSQL

echo "✓ db-o11y monitoring user created"
echo "✓ Grants applied to 'grafana' and 'bank' databases"
