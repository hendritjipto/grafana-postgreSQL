#!/usr/bin/env bash
set -e

# 'grafana' database is already created by Docker via POSTGRES_DB.
# This script creates the 'bank' database, enables pg_stat_statements
# in the grafana database, and sets up the replication user.

# Create bank database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE bank;
EOSQL

# Enable pg_stat_statements in grafana so Alloy can observe it too
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"

# Create replication user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '${REPLICATOR_PASSWORD}';
EOSQL

# Allow the replicator user to connect for replication from any host
echo "host replication replicator all md5" >> "$PGDATA/pg_hba.conf"

# Reload pg_hba.conf so the new rule takes effect immediately
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    -c "SELECT pg_reload_conf();"

echo "✓ Database 'bank' created"
echo "✓ pg_stat_statements enabled in '$POSTGRES_DB'"
echo "✓ Replication user 'replicator' created"
echo "✓ pg_hba.conf updated and reloaded"
