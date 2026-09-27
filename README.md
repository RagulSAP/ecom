# Enterprise E-Commerce Platform

An enterprise-grade e-commerce platform built with React Native (mobile), FastAPI (backend), and PostgreSQL.

## Development Status

**Current Phase**: Phase 2 — Database Design (awaiting review)

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System architecture, tech stack, AWS design |
| [Database Design](docs/database-design.md) | Complete PostgreSQL schema — all 44 tables |
| [Database ERD](docs/database-erd.md) | Entity relationship diagrams (Mermaid) |
| [Business Rules](docs/business-rules.md) | Critical business rules per domain |
| [API Plan](docs/api-plan.md) | Planned REST API endpoints |
| [ADR-001: Modular Monolith](docs/decisions/ADR-001-modular-monolith.md) | Architecture decision |
| [ADR-002: UUID Keys](docs/decisions/ADR-002-uuid-primary-keys.md) | Primary key strategy |
| [ADR-003: Order Snapshots](docs/decisions/ADR-003-order-snapshots.md) | Historical data strategy |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | React Native, Expo, TypeScript, TanStack Query, Zustand |
| Backend | Python, FastAPI, SQLAlchemy 2.x, Alembic, Celery |
| Database | PostgreSQL 16 |
| Cache | Redis |
| Cloud | AWS (ECS Fargate, RDS, ElastiCache, S3, CloudFront) |

## Project Structure (planned)

```
ecom/
├── mobile/          # React Native app (Phase 5+)
├── backend/         # FastAPI application (Phase 3+)
├── infrastructure/  # AWS CDK / Terraform (Phase 9)
├── docs/            # Architecture and design documentation
└── docker-compose.yml
```

## Development Phases

- [x] Phase 1 — Requirements & Architecture Analysis
- [x] Phase 2 — Database Design ← **CURRENT**
- [ ] Phase 2A — Database Review Gate (awaiting approval)
- [ ] Phase 3 — Backend Foundation
- [ ] Phase 4 — Backend Modules
- [ ] Phase 5 — React Native Foundation
- [ ] Phase 6 — Mobile Screens
- [ ] Phase 7 — Testing
- [ ] Phase 8 — Production Readiness
- [ ] Phase 9 — AWS Deployment
