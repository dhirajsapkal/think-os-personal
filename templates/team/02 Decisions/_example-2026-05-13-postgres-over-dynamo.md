---
uid: 01HY2MN5T7QWKBPF8RJCXD3VA0
type: decision
date: "2026-05-13"
status: accepted
deciders:
  - "@dhiraj"
  - "@maya"
  - "@sarah"
supersedes: null
---

# 2026-05-13 — Use PostgreSQL instead of DynamoDB for the events store

## Context

We evaluated two primary storage options for the events table, which will hold write-heavy audit and activity records. Initial spike used DynamoDB; the team ran a cost/complexity analysis during sprint planning.

## Decision

Use PostgreSQL (managed via RDS) as the primary events store.

## Reasoning

- **Query flexibility**: ad-hoc reporting on event data (filtering by actor, date range, event type) maps naturally to SQL; DynamoDB would require carefully managed GSIs for every access pattern.
- **Operational familiarity**: the team already operates an RDS cluster for the main application database; adding a second table is lower overhead than onboarding a new persistence stack.
- **Cost at our scale**: at projected 50M events/month, RDS with table partitioning is cheaper than DynamoDB on-demand pricing for our read/write ratio.
- **Migration path**: partitioned tables let us move cold partitions to cheaper storage or archive to S3 if volume grows unexpectedly.

## Tradeoffs accepted

- Horizontal write scaling requires partitioning discipline (accepted; the access pattern is mostly append-only).
- DynamoDB's automatic TTL-based expiry is convenient; we will implement a scheduled cleanup job in PostgreSQL instead.

## What this supersedes

None. This is the first decision on the events store.

## Revisit trigger

If single-table write throughput exceeds 5k rows/second sustained, revisit sharding strategy.
