#!/usr/bin/env bash
set -e

PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PRIMARY_HOST="${PRIMARY_HOST:-postgres-primary}"
REPLICATOR_PASSWORD="${REPLICATOR_PASSWORD}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "▶ No data found — running initial base backup from $PRIMARY_HOST..."

    # Ensure data directory exists with correct ownership
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"

    # Wait until primary is accepting connections
    until gosu postgres pg_isready -h "$PRIMARY_HOST" -q 2>/dev/null; do
        echo "  Waiting for primary to be ready..."
        sleep 2
    done

    # pg_basebackup with -R:
    #   automatically writes standby.signal and primary_conninfo
    PGPASSWORD="$REPLICATOR_PASSWORD" gosu postgres pg_basebackup \
        -h "$PRIMARY_HOST" \
        -U replicator \
        -D "$PGDATA" \
        --wal-method=stream \
        --checkpoint=fast \
        -R \
        -P

    echo "✓ Base backup complete"
    echo "✓ standby.signal and primary_conninfo written by pg_basebackup -R"
else
    echo "▶ Data directory exists — starting as standby replica..."
fi

exec gosu postgres postgres -D "$PGDATA"
