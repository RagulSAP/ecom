# System Architecture — Enterprise E-Commerce Platform

## 1. Requirements Analysis

### 1.1 Missing Requirements

The following areas are not explicitly defined in the specification and require decisions before implementation:

| # | Gap | Recommendation |
|---|-----|----------------|
| 1 | **Currency support** — Single currency (INR) or multi-currency? | Start with single configurable currency; store ISO code with every monetary record |
| 2 | **Tax model** — GST (CGST/SGST/IGST) or flat percentage? | Design for GST with configurable tax rules per product category |
| 3 | **Guest checkout** — Allowed or forced registration? | Support guest carts with session IDs; require account for order history |
| 4 | **Payment capture** — Auto-capture vs. manual authorize-then-capture? | Auto-capture for MVP; hook for manual later |
| 5 | **Inventory model** — Per-warehouse or single global inventory? | Single location initially; location-aware schema from day one |
| 6 | **Product search engine** — PostgreSQL FTS sufficient for MVP? | Yes; design abstraction layer for OpenSearch migration |
| 7 | **Return window** — Fixed days (e.g., 7/30 days) from delivery? | Configurable per category; business decision needed |
| 8 | **COD (Cash on Delivery)** — Required? | Yes — common in Indian market; treat as a payment method |
| 9 | **B2B / wholesale pricing** — Required now or later? | Not in scope; schema must not block it |
| 10 | **Digital products** — Physical goods only? | Physical goods only for MVP |
| 11 | **Platform commission model** — Fixed % or tiered? | Configurable per vendor from day one |
| 12 | **Admin portal type** — Separate React admin SPA or mobile admin? | Separate web portal (out of scope for current phase) |
| 13 | **Image storage** — S3 + CloudFront CDN? | Yes — all media via S3; URLs served through CloudFront |
| 14 | **Email provider** — SES, SendGrid, or other? | AWS SES default; abstracted for flexibility |
| 15 | **SMS provider** — Twilio, AWS SNS, or Indian provider (MSG91)? | Indian market → MSG91 or AWS SNS; abstracted |

### 1.2 Ambiguous Requirements

| # | Ambiguity | Assumption Made |
|---|-----------|-----------------|
| 1 | "Multi-vendor readiness" — vendors isolated or shared catalog? | Vendors own their products; shared category/brand taxonomy |
| 2 | "Recently viewed" — per-session or per-account? | Per-account when logged in; session-based for guests (not persisted) |
| 3 | "Product tags" — free text or controlled vocabulary? | Free text array; no separate tags table for MVP |
| 4 | "Partial cancellation" — cancel individual items or partial quantities? | Cancel individual order items; quantities cancel whole units |
| 5 | "Coupon applicable to brands" — discount all brand products? | Yes, all active products from that brand |
| 6 | "Admin role" — single super-admin or role hierarchy? | Role-based with assignable permissions |
| 7 | "Order tracking" — real-time courier API or manual updates? | Manual status updates initially; courier webhook abstraction built in |

### 1.3 Architecture Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Inventory race conditions under concurrent cart additions | HIGH | Pessimistic locking on inventory.quantity_reserved during checkout |
| Duplicate order creation on network retry | HIGH | Idempotency key per checkout request |
| Payment webhook replay | HIGH | Idempotent webhook processing with deduplication |
| Price drift between cart add and checkout | MEDIUM | Re-validate prices at checkout; display price change to user |
| Cart abandoned with reserved inventory | MEDIUM | TTL on cart reservation; cron job releases stale reservations |
| Large product catalog search latency | MEDIUM | PostgreSQL GIN indexes + FTS now; OpenSearch migration path built in |
| Financial rounding errors | HIGH | Use NUMERIC(12,2) everywhere; no FLOAT |
| Soft-delete orphan references | MEDIUM | Consistent soft-delete pattern + FK with cascade consideration |

---

## 2. System Architecture

### 2.1 Architectural Style

**Modular Monolith** — Single deployable FastAPI application structured into domain modules. Each module owns its models, schemas, services, and repository. The module boundaries are designed to allow future extraction into microservices without a database redesign.

```
┌─────────────────────────────────────────────────────────────┐
│                    React Native Mobile App                   │
│          (iOS / Android / Expo / TypeScript)                 │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS / REST
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer (AWS ALB)            │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│         ECS Fargate — FastAPI Application Container          │
│                                                             │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │   Auth   │ │ Catalog  │ │  Orders  │ │  Payments    │  │
│  │ Module   │ │ Module   │ │  Module  │ │  Module      │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │
│  │   Cart   │ │Inventory │ │Shipping  │ │Notifications │  │
│  │ Module   │ │ Module   │ │  Module  │ │  Module      │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────┘  │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Celery Workers (Background Jobs)         │  │
│  └──────────────────────────────────────────────────────┘  │
└─────┬────────────────┬───────────────┬──────────────────────┘
      │                │               │
      ▼                ▼               ▼
┌──────────┐   ┌──────────┐   ┌──────────────┐
│  RDS     │   │ElastiCach│   │     S3       │
│PostgreSQL│   │  Redis   │   │  (Media /    │
│          │   │          │   │  Static)     │
└──────────┘   └──────────┘   └──────────────┘
                                      │
                               ┌──────▼──────┐
                               │ CloudFront  │
                               │    CDN      │
                               └─────────────┘
```

### 2.2 Domain Modules

| Module | Responsibility |
|--------|---------------|
| **auth** | JWT issuance, refresh tokens, OTP, password reset |
| **users** | User accounts, roles, permissions, admin user management |
| **customers** | Customer profiles, addresses |
| **catalog** | Categories, brands, products, variants, attributes, images |
| **inventory** | Stock levels, reservations, transaction ledger |
| **cart** | Cart lifecycle, price/inventory validation, coupon application |
| **orders** | Order creation, status transitions, cancellations, returns |
| **payments** | Payment abstraction layer, webhooks, refunds |
| **shipping** | Shipment creation, tracking, courier abstraction |
| **promotions** | Coupons, discount rules, eligibility |
| **reviews** | Product ratings and reviews |
| **notifications** | Push/email/SMS dispatch abstraction |
| **vendors** | Vendor accounts, users, payout readiness |
| **admin** | Admin-specific aggregation endpoints |
| **search** | PostgreSQL FTS now; OpenSearch abstraction later |

### 2.3 Cross-Cutting Concerns

| Concern | Implementation |
|---------|---------------|
| Authentication | JWT Bearer tokens (short-lived access + long-lived refresh) |
| Authorization | Role-Based Access Control (RBAC) with permission codes |
| Logging | Structured JSON logs with request-id and correlation-id |
| Audit | Audit log table for all write operations on sensitive entities |
| Error Handling | Centralized exception handler → consistent API error envelope |
| Rate Limiting | Redis-backed sliding window rate limiter per endpoint class |
| Idempotency | Idempotency-Key header for checkout, payment, refund APIs |
| Pagination | Cursor-based for high-volume lists; offset for admin |
| API Versioning | URL path versioning `/api/v1/` |
| Health Checks | `/health`, `/ready`, `/live` endpoints |
| Config | Environment variables → Pydantic Settings; secrets via AWS Secrets Manager |
| Media | Upload to S3; serve via CloudFront signed URLs or public URLs |

### 2.4 Local Development Stack

```yaml
# docker-compose.yml services
- postgres:16          # RDS equivalent
- redis:7              # ElastiCache equivalent
- mailhog              # Email testing
- localstack           # S3/SQS/SNS local
- app (FastAPI)
- worker (Celery)
```

### 2.5 AWS Production Architecture

```
Route 53
  └── CloudFront (CDN for media)
        └── S3 (media bucket)

Route 53
  └── ALB
        └── ECS Fargate (FastAPI, auto-scaled)
              ├── RDS PostgreSQL Multi-AZ
              ├── ElastiCache Redis (cluster mode)
              ├── S3 (media, logs)
              ├── SQS (task queues for Celery)
              ├── SNS (fanout notifications)
              └── Secrets Manager (all secrets)

CloudWatch → Logs, Metrics, Alarms
WAF → ALB (OWASP rules, rate limiting, geo-blocking)
ECR → Docker image registry
IAM → Task roles, least-privilege
```

### 2.6 Security Architecture

- **Transport**: TLS 1.2+ enforced at ALB; HSTS headers
- **Authentication**: bcrypt password hashing (cost factor 12); JWT RS256 or HS256 with rotation
- **Authorization**: Every API endpoint declares required permission; enforced at middleware
- **Secrets**: Zero secrets in code/config files; all via environment → Secrets Manager
- **Input Validation**: Pydantic models enforce all input at API boundary
- **SQL Injection**: SQLAlchemy ORM with parameterized queries only
- **Rate Limiting**: Login: 5/min; OTP: 3/min; API: 1000/min per user
- **WAF**: AWS WAF on ALB for OWASP Top 10 rules
- **Audit**: All mutations on orders, payments, users, roles recorded in audit_logs

---

## 3. Technology Decisions

### Backend
| Decision | Choice | Reason |
|----------|--------|--------|
| API Framework | FastAPI | Async, type-safe, auto OpenAPI docs |
| ORM | SQLAlchemy 2.x | Mature, supports async, excellent migration tooling |
| Migrations | Alembic | De-facto standard for SQLAlchemy projects |
| Task Queue | Celery + Redis | Email/SMS dispatch, inventory cleanup, report generation |
| Caching | Redis | Session store, rate limiting, cart TTL, catalog caching |
| Validation | Pydantic v2 | Native FastAPI integration, fast, strict |

### Mobile
| Decision | Choice | Reason |
|----------|--------|--------|
| Framework | React Native + Expo | Cross-platform, large ecosystem |
| Navigation | Expo Router | File-based routing, deep link native support |
| Server State | TanStack Query | Caching, background refetch, optimistic updates |
| Client State | Zustand | Lightweight, minimal boilerplate |
| Forms | React Hook Form + Zod | Type-safe validation |
| Secure Storage | expo-secure-store | Keychain (iOS) / Keystore (Android) for tokens |

---

## 4. Scalability Considerations

| Concern | Strategy |
|---------|---------|
| Database read load | Read replicas for catalog/listing queries |
| Cart concurrency | Redis-based optimistic locking during checkout |
| Image delivery | S3 + CloudFront CDN; never serve media from app servers |
| Search at scale | PostgreSQL FTS initially; OpenSearch when >1M products |
| Background jobs | Celery workers scaled independently via ECS |
| API throughput | ECS Fargate auto-scaling on CPU/memory; target tracking |
| Database connections | PgBouncer connection pooling between app and RDS |
| Hot data | Redis caching for product listings, categories, user sessions |
