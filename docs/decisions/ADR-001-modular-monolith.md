# ADR-001: Modular Monolith over Microservices

**Date**: 2026-09-27
**Status**: Accepted

## Decision

Start with a modular monolith. Do not decompose into microservices in Phase 1-4.

## Context

The team is building a new platform. Microservices add significant operational complexity (service discovery, distributed tracing, inter-service auth, eventual consistency, network latency). These costs are not justified until the system has proven load and team has grown.

## Consequences

- Single deployable unit; simpler CI/CD
- Module boundaries are enforced by Python package structure, not network boundaries
- Each module has isolated: models, schemas, services, repositories
- Modules do not import each other's service layer — only repositories or via explicit service calls
- Future extraction to microservices is possible if a module's load justifies it
- Database remains shared; splitting the DB later requires careful migration planning
