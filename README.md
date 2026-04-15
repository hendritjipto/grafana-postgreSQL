# Grafana Database Observability — PostgreSQL

A self-contained Docker Compose environment for observing PostgreSQL with Grafana Alloy, Grafana Enterprise, and Grafana Cloud. Includes primary + replica streaming replication, Grafana Database Observability, and a seeded bank demo database.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Docker Network                            │
│                                                                  │
│  ┌──────────────────┐  streaming    ┌──────────────────┐         │
│  │ postgres-primary │ ────────────► │ postgres-replica │         │
│  │    :5432         │  replication  │    :5433         │         │
│  └──┬────────────┬──┘               └──────┬───────────┘         │
│     │            │                         │                     │
│  backend      scrape                    scrape                   │
│     DB        metrics                   metrics                  │
│     │            └─────────────────────────┘                     │
│     │                        │                                   │
│     ▼                        ▼                                   │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────┐    │
│  │  grafana-    │  │  grafana-alloy   │  │  grafana-pdc-    │    │
│  │  enterprise  │  │    :12345        │  │  agent           │    │
│  │  :3000       │  └────────┬─────────┘  └─────────┬────────┘    │
│  └──────────────┘           │ push                 │ secure      │
│                             │ metrics + logs       │ tunnel      │
└─────────────────────────────┼──────────────────────┼─────────────┘
                              └──────────┬───────────┘
                                         ▼
                               ┌──────────────────┐
                               │   Grafana Cloud  │
                               │  Metrics + Logs  │
                               └──────────────────┘
```

| Service | Role |
|---|---|
| `postgres-primary` | Primary PostgreSQL instance. Hosts the `grafana` and `bank` databases. Configured for streaming replication |
| `postgres-replica` | Standby replica. Receives WAL stream from primary via `pg_basebackup` |
| `grafana-alloy` | Collects metrics from both PostgreSQL instances and ships them to Grafana Cloud. Also collects query-level telemetry via Database Observability |
| `grafana-enterprise` | Local Grafana UI backed by the primary database |
| `grafana-pdc-agent` | Private Data Connect agent — creates a secure tunnel so Grafana Cloud can query the local environment |

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2
- A [Grafana Cloud](https://grafana.com/auth/sign-up) account (free tier works)
- Grafana Enterprise license — optional, leave blank to run in 30-day trial mode

---

## Quick Start

**1. Clone the repository**

```bash
git clone https://github.com/your-username/grafana-postgreSQL.git
cd grafana-postgreSQL
```

**2. Configure environment variables**

```bash
cp .env.example .env
```

Open `.env` and fill in your credentials. See the [Environment Variables](#environment-variables) section below.

**3. Configure secrets**

```bash
cp secrets/postgres_dsn.example secrets/postgres_dsn
cp secrets/postgres_dsn_replica.example secrets/postgres_dsn_replica
```

Edit each file and replace `CHANGE_ME` with your `DB_O11Y_PASSWORD` value from `.env`.

**4. Start the stack**

```bash
docker compose up -d
```

**5. Access the services**

| Service | URL |
|---|---|
| Grafana Enterprise | http://localhost:3000 |
| Alloy UI | http://localhost:12345 |
| PostgreSQL primary | `localhost:5432` |
| PostgreSQL replica | `localhost:5433` |

---

## Environment Variables

Copy `.env.example` to `.env` and fill in the following:

| Variable | Description | Where to find it |
|---|---|---|
| `POSTGRES_USER` | PostgreSQL superuser name | Your choice |
| `POSTGRES_PASSWORD` | PostgreSQL superuser password | Your choice |
| `POSTGRES_DB` | Default database name | Your choice (default: `grafana`) |
| `DB_O11Y_PASSWORD` | Password for the `db-o11y` monitoring user | Your choice |
| `REPLICATOR_PASSWORD` | Password for the `replicator` streaming replication user | Your choice |
| `GF_ADMIN_USER` | Grafana admin username | Your choice |
| `GF_ADMIN_PASSWORD` | Grafana admin password | Your choice |
| `GF_ENTERPRISE_LICENSE_TEXT` | Grafana Enterprise license key | Grafana Cloud portal — leave blank for trial |
| `GCLOUD_PDC_SIGNING_TOKEN` | PDC agent signing token | Grafana Cloud → Private Data Connect |
| `GCLOUD_HOSTED_GRAFANA_ID` | Grafana Cloud stack ID | Grafana Cloud → Stack → Details |
| `GCLOUD_PDC_CLUSTER` | PDC cluster name | Grafana Cloud → Private Data Connect |
| `GCLOUD_HOSTED_METRICS_URL` | Prometheus remote write endpoint | Grafana Cloud → Stack → Details |
| `GCLOUD_HOSTED_METRICS_ID` | Prometheus remote write username | Grafana Cloud → Stack → Details |
| `GCLOUD_HOSTED_LOGS_URL` | Loki push endpoint | Grafana Cloud → Stack → Details |
| `GCLOUD_HOSTED_LOGS_ID` | Loki username | Grafana Cloud → Stack → Details |
| `GCLOUD_RW_API_KEY` | API token with `MetricsPublisher` + `LogsPublisher` scopes | Grafana Cloud → API Keys |

---

## Secrets

The `secrets/` directory contains DSN files read by Grafana Alloy at runtime with `is_secret = true` — this ensures the connection strings never appear in Alloy logs or the UI.

| File | Points to |
|---|---|
| `secrets/postgres_dsn` | Primary: `postgresql://db-o11y:<password>@postgres-primary:5432/grafana?sslmode=disable` |
| `secrets/postgres_dsn_replica` | Replica: `postgresql://db-o11y:<password>@postgres-replica:5432/grafana?sslmode=disable` |

Both files are in `.gitignore`. The `.example` variants are safe to commit.

---

## What's Monitored

### Infrastructure metrics — both primary and replica

Collected via `prometheus.exporter.postgres` with separate pipelines per instance. Each metric is labeled `instance="postgres-primary"` or `instance="postgres-replica"`.

| Collector | Source | What it monitors |
|---|---|---|
| `stat_statements` | `pg_stat_statements` | Per-query aggregates: execution time, call count, rows, I/O |
| `database` | `pg_database` | Database size |
| `locks` | `pg_locks` | Lock contention by mode |
| `long_running_transactions` | `pg_stat_activity` | Stale open transactions |
| `postmaster` | `pg_postmaster_start_time()` | Unexpected restarts |
| `replication` | `pg_stat_replication` | Replica lag and WAL position |
| `stat_bgwriter` | `pg_stat_bgwriter` | Checkpoint and background writer pressure |
| `stat_database` | `pg_stat_database` | Transaction rate, cache hit ratio, deadlocks |
| `stat_user_tables` | `pg_stat_user_tables` | Sequential scans, dead tuples, autovacuum timing |
| `statio_user_indexes` | `pg_statio_user_indexes` | Index cache hit ratio |

### Database Observability — primary only

Collected via `database_observability.postgres`. Produces structured log events forwarded to Loki in addition to metrics.

| Collector | What it produces |
|---|---|
| `query_details` | Normalized SQL catalog with query fingerprints |
| `query_samples` | In-flight query snapshots from `pg_stat_activity` including wait events |
| `schema_details` | Tables, columns, and indexes from system catalogs (powers the knowledge graph) |
| `explain_plans` | Automatic `EXPLAIN` output on sampled slow queries |
| `logs` | PostgreSQL log processing and error metrics |

---

## Demo Database Schema

The `bank` database is a realistic financial schema seeded with sample data, designed to generate meaningful query telemetry for observability testing.

See [SCHEMA.md](SCHEMA.md) for the full entity-relationship diagram and table descriptions.

| Table | Seed rows | Description |
|---|---|---|
| `branches` | 5 | Bank branch locations |
| `employees` | 10 | Staff assigned to branches |
| `customers` | 20 | Individual bank customers |
| `accounts` | 30 | Checking, savings, credit, and business accounts |
| `cards` | 16 | Debit and credit cards per account |
| `transactions` | 68 | Every financial event on an account |
| `transfers` | 4 | Internal transfers linking two accounts |
| `loans` | 8 | Mortgage, personal, auto, and business loans |

---

## Ports

| Service | Host port | Protocol |
|---|---|---|
| Grafana Enterprise | `3000` | HTTP |
| Alloy UI / health | `12345` | HTTP |
| PostgreSQL primary | `5432` | TCP |
| PostgreSQL replica | `5433` | TCP |
