# API Plan — Enterprise E-Commerce Platform

> This document outlines the planned REST API surface. Implementation begins in Phase 3 after database approval.
> Base path: `/api/v1/`

---

## API Conventions

### Request/Response Envelope

**Success (list)**:
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 154,
    "total_pages": 8
  }
}
```

**Success (single)**:
```json
{
  "data": { ... }
}
```

**Error**:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable message",
    "details": [
      { "field": "email", "message": "Invalid email format" }
    ],
    "request_id": "req_abc123"
  }
}
```

### Standard Query Parameters (List APIs)

| Parameter | Type | Description |
|-----------|------|-------------|
| `page` | integer | Page number (default: 1) |
| `page_size` | integer | Items per page (default: 20, max: 100) |
| `search` | string | Full-text search query |
| `sort` | string | Field name; prefix with `-` for descending (e.g., `-created_at`) |
| `filter[field]` | string | Field-level filter |

### HTTP Status Codes

| Code | Usage |
|------|-------|
| 200 | OK |
| 201 | Created |
| 204 | No Content (DELETE) |
| 400 | Bad Request / Validation Error |
| 401 | Unauthenticated |
| 403 | Forbidden (insufficient permissions) |
| 404 | Not Found |
| 409 | Conflict (duplicate, state conflict) |
| 422 | Unprocessable Entity |
| 429 | Rate Limited |
| 500 | Internal Server Error |

---

## Module 1: Authentication

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/auth/register` | Register new customer | Public |
| POST | `/auth/login` | Login (returns access + refresh token) | Public |
| POST | `/auth/logout` | Invalidate refresh token | Required |
| POST | `/auth/refresh` | Exchange refresh token for new access token | Refresh token |
| POST | `/auth/forgot-password` | Send OTP to email | Public |
| POST | `/auth/reset-password` | Reset password using OTP | Public |
| POST | `/auth/verify-email` | Verify email using OTP | Required |
| POST | `/auth/resend-verification` | Resend verification OTP | Required |

**Rate limits**: Login: 5/min; OTP requests: 3/15min per identifier.

---

## Module 2: Users (Admin)

| Method | Path | Description | Permission |
|--------|------|-------------|-----------|
| GET | `/admin/users` | List all users | user:list |
| GET | `/admin/users/{id}` | Get user details | user:read |
| POST | `/admin/users` | Create admin/staff user | user:create |
| PATCH | `/admin/users/{id}` | Update user | user:update |
| DELETE | `/admin/users/{id}` | Soft-delete user | user:delete |
| POST | `/admin/users/{id}/roles` | Assign role | user:manage_roles |
| DELETE | `/admin/users/{id}/roles/{role_id}` | Remove role | user:manage_roles |
| POST | `/admin/users/{id}/activate` | Reactivate user | user:update |
| POST | `/admin/users/{id}/deactivate` | Deactivate user | user:update |

---

## Module 3: Customer Profile

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/customers/me` | Get own profile | Customer |
| PATCH | `/customers/me` | Update profile | Customer |
| GET | `/customers/me/addresses` | List addresses | Customer |
| POST | `/customers/me/addresses` | Add address | Customer |
| PUT | `/customers/me/addresses/{id}` | Update address | Customer |
| DELETE | `/customers/me/addresses/{id}` | Delete address | Customer |
| PATCH | `/customers/me/addresses/{id}/default` | Set default address | Customer |

---

## Module 4: Product Catalog

### Categories
| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/categories` | List root/all categories | Public |
| GET | `/categories/{id}` | Get category detail | Public |
| GET | `/categories/{id}/children` | Get subcategories | Public |
| POST | `/admin/categories` | Create category | catalog:create |
| PUT | `/admin/categories/{id}` | Update category | catalog:update |
| DELETE | `/admin/categories/{id}` | Delete category | catalog:delete |

### Brands
| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/brands` | List brands | Public |
| GET | `/brands/{id}` | Get brand | Public |
| POST | `/admin/brands` | Create brand | catalog:create |
| PUT | `/admin/brands/{id}` | Update brand | catalog:update |
| DELETE | `/admin/brands/{id}` | Delete brand | catalog:delete |

### Products
| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/products` | List products (search, filter, sort) | Public |
| GET | `/products/{id}` | Get product detail with variants | Public |
| GET | `/products/{id}/reviews` | Get product reviews | Public |
| GET | `/products/{id}/related` | Get related products | Public |
| POST | `/admin/products` | Create product | product:create |
| PUT | `/admin/products/{id}` | Update product | product:update |
| DELETE | `/admin/products/{id}` | Delete product | product:delete |
| POST | `/admin/products/{id}/variants` | Add variant | product:create |
| PUT | `/admin/products/{id}/variants/{vid}` | Update variant | product:update |
| DELETE | `/admin/products/{id}/variants/{vid}` | Delete variant | product:delete |
| POST | `/admin/products/{id}/images` | Upload image | product:update |
| DELETE | `/admin/products/{id}/images/{iid}` | Delete image | product:update |

**Key filters for GET /products**:
- `category_id`, `brand_id`, `vendor_id`
- `min_price`, `max_price`
- `in_stock` (boolean)
- `is_featured`
- `tag`
- `attribute[size]`, `attribute[color]` (dynamic attribute filters)

---

## Module 5: Inventory (Admin)

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/admin/inventory` | List inventory levels | inventory:read |
| GET | `/admin/inventory/{variant_id}` | Get variant stock | inventory:read |
| POST | `/admin/inventory/{variant_id}/adjust` | Manual adjustment | inventory:adjust |
| GET | `/admin/inventory/{variant_id}/transactions` | Inventory ledger | inventory:read |
| GET | `/admin/inventory/low-stock` | Low stock report | inventory:read |

---

## Module 6: Cart

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/cart` | Get current cart | Optional (session fallback) |
| POST | `/cart/items` | Add item to cart | Optional |
| PATCH | `/cart/items/{id}` | Update item quantity | Optional |
| DELETE | `/cart/items/{id}` | Remove item from cart | Optional |
| POST | `/cart/coupon` | Apply coupon | Optional |
| DELETE | `/cart/coupon` | Remove coupon | Optional |
| GET | `/cart/validate` | Validate cart (prices, stock) before checkout | Optional |

---

## Module 7: Orders

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/orders` | Create order from cart (checkout) | Customer |
| GET | `/orders` | List customer orders | Customer |
| GET | `/orders/{id}` | Get order detail | Customer (own) |
| POST | `/orders/{id}/cancel` | Cancel order | Customer (own) |
| POST | `/orders/{id}/items/{item_id}/cancel` | Cancel order item | Customer (own) |
| GET | `/admin/orders` | List all orders | order:list |
| GET | `/admin/orders/{id}` | Get order (admin) | order:read |
| PATCH | `/admin/orders/{id}/status` | Update order status | order:update |
| POST | `/admin/orders/{id}/refund` | Initiate refund | order:refund |

**Checkout (POST /orders) flow**:
1. Validate cart items (prices, stock)
2. Reserve inventory
3. Create order with snapshots
4. Create payment record
5. Return order ID + payment session ID
6. Client redirects to payment gateway
7. Webhook confirms payment → update order status

---

## Module 8: Payments

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| POST | `/payments/{order_id}/initiate` | Create payment session | Customer |
| POST | `/payments/{order_id}/verify` | Server-side payment verification | Customer |
| POST | `/payments/webhooks/razorpay` | Razorpay webhook receiver | Webhook signature |
| POST | `/payments/webhooks/stripe` | Stripe webhook receiver | Webhook signature |
| GET | `/orders/{id}/payment` | Get payment status | Customer (own) |
| POST | `/admin/orders/{id}/refund` | Initiate refund | order:refund |

---

## Module 9: Shipping

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/orders/{id}/shipments` | Get shipments for order | Customer (own) |
| GET | `/orders/{id}/shipments/{sid}/tracking` | Get tracking events | Customer (own) |
| POST | `/admin/shipments` | Create shipment | shipment:create |
| PATCH | `/admin/shipments/{id}` | Update shipment status | shipment:update |
| POST | `/admin/shipments/webhooks/{provider}` | Courier webhook | Webhook |

---

## Module 10: Wishlist

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/customers/me/wishlist` | Get wishlist | Customer |
| POST | `/customers/me/wishlist/items` | Add to wishlist | Customer |
| DELETE | `/customers/me/wishlist/items/{id}` | Remove from wishlist | Customer |

---

## Module 11: Reviews

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/products/{id}/reviews` | Get product reviews | Public |
| POST | `/products/{id}/reviews` | Submit review | Customer |
| PUT | `/products/{id}/reviews/{rid}` | Update own review | Customer (own) |
| DELETE | `/products/{id}/reviews/{rid}` | Delete own review | Customer (own) |
| POST | `/reviews/{id}/helpful` | Mark review helpful | Customer |
| GET | `/admin/reviews` | List reviews (pending moderation) | review:list |
| PATCH | `/admin/reviews/{id}/approve` | Approve review | review:moderate |
| PATCH | `/admin/reviews/{id}/reject` | Reject review | review:moderate |

---

## Module 12: Promotions (Admin)

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/admin/coupons` | List coupons | coupon:list |
| GET | `/admin/coupons/{id}` | Get coupon | coupon:read |
| POST | `/admin/coupons` | Create coupon | coupon:create |
| PUT | `/admin/coupons/{id}` | Update coupon | coupon:update |
| DELETE | `/admin/coupons/{id}` | Delete coupon | coupon:delete |
| GET | `/admin/coupons/{id}/usages` | Coupon usage report | coupon:read |

---

## Module 13: Notifications

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/notifications` | Get in-app notifications | Customer |
| PATCH | `/notifications/{id}/read` | Mark as read | Customer |
| POST | `/notifications/read-all` | Mark all as read | Customer |
| GET | `/notifications/preferences` | Get notification preferences | Customer |
| PUT | `/notifications/preferences` | Update preferences | Customer |
| POST | `/devices/tokens` | Register push token | Customer |
| DELETE | `/devices/tokens/{token}` | Unregister push token | Customer |

---

## Module 14: Search

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/search/products` | Product search with FTS | Public |
| GET | `/search/suggestions` | Autocomplete suggestions | Public |

---

## Module 15: Admin Dashboard

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/admin/dashboard/summary` | Key metrics | admin:dashboard |
| GET | `/admin/reports/sales` | Sales report | report:read |
| GET | `/admin/reports/inventory` | Inventory report | report:read |
| GET | `/admin/reports/customers` | Customer report | report:read |
| GET | `/admin/audit-logs` | Audit log viewer | audit:read |

---

## System Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/health` | Health check (always 200) | Public |
| GET | `/ready` | Readiness (DB + Redis connected) | Public |
| GET | `/live` | Liveness probe | Public |
| GET | `/docs` | Swagger UI (disabled in production) | Internal |
| GET | `/openapi.json` | OpenAPI spec | Internal |

---

## Permission Codes (RBAC)

| Module | Permission Codes |
|--------|----------------|
| users | user:list, user:read, user:create, user:update, user:delete, user:manage_roles |
| catalog | catalog:create, catalog:update, catalog:delete |
| product | product:create, product:update, product:delete |
| inventory | inventory:read, inventory:adjust |
| order | order:list, order:read, order:update, order:refund, order:cancel |
| payment | payment:read, payment:refund |
| shipment | shipment:create, shipment:update, shipment:read |
| coupon | coupon:list, coupon:read, coupon:create, coupon:update, coupon:delete |
| review | review:list, review:moderate |
| report | report:read |
| audit | audit:read |
| admin | admin:dashboard |

---

## System Roles (Pre-seeded)

| Role | Permissions |
|------|------------|
| `super_admin` | All permissions |
| `admin` | All except user:manage_roles, audit:read |
| `customer_support` | order:list, order:read, order:update, refund initiation |
| `catalog_manager` | All catalog, product, inventory permissions |
| `customer` | Own orders, cart, wishlist, profile (enforced by ownership checks, not RBAC) |
| `vendor_admin` | Own product/inventory/order permissions (scoped to vendor_id) |
