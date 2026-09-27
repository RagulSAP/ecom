# ADR-002: UUID Primary Keys

**Date**: 2026-09-27
**Status**: Accepted

## Decision

Use UUID v4 as primary keys for all tables except `audit_logs` (BIGSERIAL).

## Context

The platform must be designed for multi-region and potential sharding scenarios. Sequential integer PKs would collide if records are ever merged across environments or shards.

## Consequences

- UUIDs can be generated client-side without a round-trip (useful for idempotency)
- Slightly larger index footprint (16 bytes vs 8 bytes for BIGINT)
- Less human-readable in debugging — mitigated by human-readable order numbers and user-facing IDs
- `audit_logs` uses BIGSERIAL for insert performance and simpler sequence ordering
- gen_random_uuid() (PostgreSQL 13+) is used; no uuid-ossp extension required
