# Database Design — Enterprise E-Commerce Platform

## Overview

- **RDBMS**: PostgreSQL 16
- **Primary Key Strategy**: UUID v4 everywhere (enables future sharding / federation)
- **Monetary Types**: NUMERIC(12,2) for all prices, amounts, taxes; NEVER FLOAT
- **Timestamps**: TIMESTAMP WITH TIME ZONE (UTC storage)
- **Soft Deletes**: `deleted_at TIMESTAMPTZ NULL` on tables that require it
- **Audit Columns**: `created_at`, `updated_at` on every table
- **Extensions Required**: `uuid-ossp` or `gen_random_uuid()` (PG 13+), `pg_trgm` (trigram search), optionally `ltree` (category hierarchy)

---

## Domain 1: Identity & Access Management

### Table: `users`

**Purpose**: Core identity record. Stores authentication credentials and account-level flags for all user types (customers, admins, vendor staff).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `email` | VARCHAR(255) | NOT NULL | — | Unique, lowercase |
| `phone` | VARCHAR(20) | NULL | — | Unique when set; E.164 format |
| `password_hash` | VARCHAR(255) | NOT NULL | — | bcrypt hash |
| `first_name` | VARCHAR(100) | NOT NULL | — | |
| `last_name` | VARCHAR(100) | NOT NULL | — | |
| `is_active` | BOOLEAN | NOT NULL | true | Account enabled |
| `is_verified` | BOOLEAN | NOT NULL | false | Email verified |
| `is_staff` | BOOLEAN | NOT NULL | false | Can access admin features |
| `last_login_at` | TIMESTAMPTZ | NULL | — | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `deleted_at` | TIMESTAMPTZ | NULL | — | Soft delete |

**Constraints**:
- PK: `id`
- UNIQUE: `email`
- UNIQUE: `phone` (partial index WHERE phone IS NOT NULL)
- CHECK: `email ~* '^[^@]+@[^@]+\.[^@]+$'`

**Indexes**:
- `idx_users_email` ON `email` (unique)
- `idx_users_phone` ON `phone` WHERE phone IS NOT NULL (unique)
- `idx_users_deleted_at` ON `deleted_at` WHERE deleted_at IS NULL (partial — active users)

**Soft Delete**: Yes (`deleted_at`)

---

### Table: `roles`

**Purpose**: Named roles that group permissions. System roles (customer, admin, vendor_admin) are protected from deletion.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `name` | VARCHAR(100) | NOT NULL | — | e.g., "super_admin", "customer", "vendor_admin" |
| `description` | TEXT | NULL | — | |
| `is_system` | BOOLEAN | NOT NULL | false | System roles cannot be deleted |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `name`

---

### Table: `permissions`

**Purpose**: Granular permission codes mapped to API operations. Format: `module:action` (e.g., `product:create`).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `code` | VARCHAR(100) | NOT NULL | — | e.g., "order:read", "product:delete" |
| `module` | VARCHAR(50) | NOT NULL | — | e.g., "order", "product" |
| `description` | TEXT | NULL | — | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `code`

**Indexes**:
- `idx_permissions_module` ON `module`

---

### Table: `role_permissions`

**Purpose**: Many-to-many join between roles and permissions.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `role_id` | UUID | NOT NULL | — | FK → roles.id |
| `permission_id` | UUID | NOT NULL | — | FK → permissions.id |

**Constraints**:
- PK: (`role_id`, `permission_id`)
- FK: `role_id` → `roles.id` ON DELETE CASCADE
- FK: `permission_id` → `permissions.id` ON DELETE CASCADE

---

### Table: `user_roles`

**Purpose**: Assigns roles to users. Records who granted the role and when.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `user_id` | UUID | NOT NULL | — | FK → users.id |
| `role_id` | UUID | NOT NULL | — | FK → roles.id |
| `granted_by` | UUID | NULL | — | FK → users.id |
| `granted_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: (`user_id`, `role_id`)
- FK: `user_id` → `users.id` ON DELETE CASCADE
- FK: `role_id` → `roles.id` ON DELETE RESTRICT
- FK: `granted_by` → `users.id` ON DELETE SET NULL

---

### Table: `refresh_tokens`

**Purpose**: Tracks issued refresh tokens (token rotation). Hashed storage — raw token is never stored.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `user_id` | UUID | NOT NULL | — | FK → users.id |
| `token_hash` | VARCHAR(255) | NOT NULL | — | SHA-256 hash of raw token |
| `expires_at` | TIMESTAMPTZ | NOT NULL | — | |
| `revoked_at` | TIMESTAMPTZ | NULL | — | NULL = active |
| `ip_address` | INET | NULL | — | |
| `user_agent` | VARCHAR(500) | NULL | — | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `token_hash`
- FK: `user_id` → `users.id` ON DELETE CASCADE

**Indexes**:
- `idx_refresh_tokens_user_id` ON `user_id`
- `idx_refresh_tokens_hash` ON `token_hash` (unique)
- `idx_refresh_tokens_expires` ON `expires_at` — for cleanup jobs

---

### Table: `otp_verifications`

**Purpose**: Stores OTP codes for email/phone verification and password reset.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `user_id` | UUID | NULL | — | FK → users.id; null for pre-registration |
| `identifier` | VARCHAR(255) | NOT NULL | — | Email or phone number |
| `purpose` | VARCHAR(50) | NOT NULL | — | CHECK: email_verification, phone_verification, password_reset |
| `otp_hash` | VARCHAR(255) | NOT NULL | — | bcrypt/SHA hash of OTP |
| `expires_at` | TIMESTAMPTZ | NOT NULL | — | 10 minutes from creation |
| `verified_at` | TIMESTAMPTZ | NULL | — | Set on success |
| `attempts` | SMALLINT | NOT NULL | 0 | Increment on each failed attempt |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `user_id` → `users.id` ON DELETE CASCADE
- CHECK: `purpose IN ('email_verification', 'phone_verification', 'password_reset')`
- CHECK: `attempts <= 3`

**Indexes**:
- `idx_otp_identifier_purpose` ON (`identifier`, `purpose`) WHERE verified_at IS NULL

---

## Domain 2: Customer

### Table: `customers`

**Purpose**: Extended profile for users with the "customer" role. One-to-one with users.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `user_id` | UUID | NOT NULL | — | FK → users.id UNIQUE |
| `display_name` | VARCHAR(200) | NULL | — | Public display name |
| `avatar_url` | VARCHAR(500) | NULL | — | S3/CDN URL |
| `date_of_birth` | DATE | NULL | — | |
| `gender` | VARCHAR(20) | NULL | — | CHECK: male, female, other, prefer_not_to_say |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `user_id`
- FK: `user_id` → `users.id` ON DELETE CASCADE

---

### Table: `customer_addresses`

**Purpose**: Physical addresses for customers. Multiple per customer; one default.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `customer_id` | UUID | NOT NULL | — | FK → customers.id |
| `label` | VARCHAR(50) | NULL | — | e.g., "Home", "Work" |
| `first_name` | VARCHAR(100) | NOT NULL | — | |
| `last_name` | VARCHAR(100) | NOT NULL | — | |
| `phone` | VARCHAR(20) | NOT NULL | — | Delivery contact |
| `address_line1` | VARCHAR(255) | NOT NULL | — | |
| `address_line2` | VARCHAR(255) | NULL | — | Apartment, suite |
| `city` | VARCHAR(100) | NOT NULL | — | |
| `state` | VARCHAR(100) | NOT NULL | — | State / province |
| `postal_code` | VARCHAR(20) | NOT NULL | — | |
| `country` | CHAR(2) | NOT NULL | 'IN' | ISO 3166-1 alpha-2 |
| `is_default` | BOOLEAN | NOT NULL | false | |
| `is_active` | BOOLEAN | NOT NULL | true | Soft delete alternative |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `customer_id` → `customers.id` ON DELETE CASCADE

**Indexes**:
- `idx_customer_addresses_customer_id` ON `customer_id`
- Partial unique: UNIQUE (`customer_id`) WHERE `is_default = true` — enforces single default per customer

**Business Rule**: Only one address per customer can have is_default = true. Enforced via partial unique index.

---

## Domain 3: Vendor (Multi-Vendor Readiness)

### Table: `vendors`

**Purpose**: Seller/merchant accounts. Platform starts single-vendor but schema supports multi-vendor.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `name` | VARCHAR(255) | NOT NULL | — | Business name |
| `slug` | VARCHAR(255) | NOT NULL | — | URL-safe identifier |
| `description` | TEXT | NULL | — | |
| `email` | VARCHAR(255) | NOT NULL | — | Business contact email |
| `phone` | VARCHAR(20) | NULL | — | |
| `logo_url` | VARCHAR(500) | NULL | — | S3/CDN URL |
| `status` | VARCHAR(20) | NOT NULL | 'pending' | CHECK: pending, active, suspended, deactivated |
| `commission_rate` | NUMERIC(5,2) | NOT NULL | 0.00 | Platform commission % |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `deleted_at` | TIMESTAMPTZ | NULL | — | Soft delete |

**Constraints**:
- PK: `id`
- UNIQUE: `slug`
- UNIQUE: `email`
- CHECK: `commission_rate >= 0 AND commission_rate <= 100`
- CHECK: `status IN ('pending', 'active', 'suspended', 'deactivated')`

---

### Table: `vendor_users`

**Purpose**: Links platform users to vendors with a vendor-specific role.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `vendor_id` | UUID | NOT NULL | — | FK → vendors.id |
| `user_id` | UUID | NOT NULL | — | FK → users.id |
| `vendor_role` | VARCHAR(30) | NOT NULL | — | CHECK: owner, admin, staff |
| `is_active` | BOOLEAN | NOT NULL | true | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: (`vendor_id`, `user_id`)
- FK: `vendor_id` → `vendors.id` ON DELETE CASCADE
- FK: `user_id` → `users.id` ON DELETE CASCADE
- CHECK: `vendor_role IN ('owner', 'admin', 'staff')`

---

## Domain 4: Product Catalog

### Table: `categories`

**Purpose**: Hierarchical product classification. Self-referential tree structure.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `parent_id` | UUID | NULL | — | FK → categories.id (self-ref) |
| `name` | VARCHAR(200) | NOT NULL | — | |
| `slug` | VARCHAR(255) | NOT NULL | — | Unique, URL-safe |
| `description` | TEXT | NULL | — | |
| `image_url` | VARCHAR(500) | NULL | — | |
| `display_order` | INTEGER | NOT NULL | 0 | Sort within siblings |
| `level` | SMALLINT | NOT NULL | 0 | 0 = root |
| `path` | VARCHAR(1000) | NOT NULL | — | Materialized path e.g. "electronics/phones/smartphones" |
| `is_active` | BOOLEAN | NOT NULL | true | |
| `meta_title` | VARCHAR(255) | NULL | — | SEO |
| `meta_description` | TEXT | NULL | — | SEO |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `deleted_at` | TIMESTAMPTZ | NULL | — | Soft delete |

**Constraints**:
- PK: `id`
- UNIQUE: `slug`
- FK: `parent_id` → `categories.id` ON DELETE RESTRICT

**Indexes**:
- `idx_categories_parent_id` ON `parent_id`
- `idx_categories_path` ON `path` (for prefix-based hierarchy queries)
- `idx_categories_active` ON `is_active` WHERE `is_active = true`

**Design Note**: Materialized path (`path`) is maintained by the application on insert/update. This enables efficient subtree queries without recursive CTEs. If the hierarchy becomes very deep or changes frequently, consider the `ltree` PostgreSQL extension.

---

### Table: `brands`

**Purpose**: Product brand/manufacturer records.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `name` | VARCHAR(200) | NOT NULL | — | |
| `slug` | VARCHAR(255) | NOT NULL | — | |
| `description` | TEXT | NULL | — | |
| `logo_url` | VARCHAR(500) | NULL | — | |
| `website_url` | VARCHAR(500) | NULL | — | |
| `is_active` | BOOLEAN | NOT NULL | true | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `deleted_at` | TIMESTAMPTZ | NULL | — | Soft delete |

**Constraints**:
- PK: `id`
- UNIQUE: `slug`

---

### Table: `attribute_groups`

**Purpose**: Groups related attributes (e.g., "Physical Dimensions", "Display"). Organizes product specification UI.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `name` | VARCHAR(100) | NOT NULL | — | |
| `display_order` | INTEGER | NOT NULL | 0 | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `name`

---

### Table: `attribute_definitions`

**Purpose**: Defines the attribute types that variants can have (e.g., Size, Color, Material).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `group_id` | UUID | NULL | — | FK → attribute_groups.id |
| `name` | VARCHAR(100) | NOT NULL | — | e.g., "Size" |
| `code` | VARCHAR(100) | NOT NULL | — | e.g., "size" (machine name) |
| `input_type` | VARCHAR(30) | NOT NULL | 'select' | CHECK: select, text, number, boolean |
| `unit` | VARCHAR(20) | NULL | — | e.g., "cm", "kg" |
| `is_filterable` | BOOLEAN | NOT NULL | false | Show in product filters |
| `is_variant_attribute` | BOOLEAN | NOT NULL | false | Used to define variants |
| `display_order` | INTEGER | NOT NULL | 0 | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `code`
- FK: `group_id` → `attribute_groups.id` ON DELETE SET NULL

---

### Table: `products`

**Purpose**: Master product record. A product is a sellable item that may have multiple variants (e.g., a T-Shirt in various sizes/colors).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `vendor_id` | UUID | NULL | — | FK → vendors.id; NULL = platform product |
| `category_id` | UUID | NOT NULL | — | FK → categories.id |
| `brand_id` | UUID | NULL | — | FK → brands.id |
| `name` | VARCHAR(500) | NOT NULL | — | |
| `slug` | VARCHAR(600) | NOT NULL | — | URL-safe, unique |
| `short_description` | TEXT | NULL | — | ≤ 500 chars; used in listings |
| `description` | TEXT | NULL | — | Full HTML/Markdown description |
| `status` | VARCHAR(20) | NOT NULL | 'draft' | CHECK: draft, active, inactive, archived |
| `is_featured` | BOOLEAN | NOT NULL | false | Featured on homepage |
| `meta_title` | VARCHAR(255) | NULL | — | SEO |
| `meta_description` | TEXT | NULL | — | SEO |
| `tags` | TEXT[] | NULL | '{}' | Free-text tag array |
| `search_vector` | TSVECTOR | NULL | — | GIN-indexed FTS vector |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `deleted_at` | TIMESTAMPTZ | NULL | — | Soft delete |

**Constraints**:
- PK: `id`
- UNIQUE: `slug`
- FK: `vendor_id` → `vendors.id` ON DELETE SET NULL
- FK: `category_id` → `categories.id` ON DELETE RESTRICT
- FK: `brand_id` → `brands.id` ON DELETE SET NULL
- CHECK: `status IN ('draft', 'active', 'inactive', 'archived')`

**Indexes**:
- `idx_products_slug` ON `slug` (unique)
- `idx_products_category_id` ON `category_id`
- `idx_products_brand_id` ON `brand_id`
- `idx_products_vendor_id` ON `vendor_id`
- `idx_products_status` ON `status`
- `idx_products_search_vector` GIN ON `search_vector`
- `idx_products_tags` GIN ON `tags`
- Composite: `idx_products_active_category` ON (`category_id`, `status`) WHERE `deleted_at IS NULL`

**Trigger**: Update `search_vector` on INSERT/UPDATE using `to_tsvector('english', name || ' ' || coalesce(short_description,''))`.

---

### Table: `product_variants`

**Purpose**: A specific purchasable unit of a product. Holds SKU, pricing, and weight. Example: "T-Shirt Size=L, Color=Black".

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `product_id` | UUID | NOT NULL | — | FK → products.id |
| `sku` | VARCHAR(100) | NOT NULL | — | Globally unique |
| `name` | VARCHAR(255) | NOT NULL | — | e.g., "Black / L" (auto-generated or manual) |
| `price` | NUMERIC(12,2) | NOT NULL | — | Sale/current price |
| `compare_at_price` | NUMERIC(12,2) | NULL | — | Original price (for discount display) |
| `cost_price` | NUMERIC(12,2) | NULL | — | Internal cost (not exposed to customers) |
| `weight_grams` | INTEGER | NULL | — | Weight in grams for shipping |
| `is_default` | BOOLEAN | NOT NULL | false | Exactly one per product |
| `is_active` | BOOLEAN | NOT NULL | true | |
| `sort_order` | INTEGER | NOT NULL | 0 | Display ordering within product |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `sku`
- FK: `product_id` → `products.id` ON DELETE CASCADE
- CHECK: `price > 0`
- CHECK: `compare_at_price IS NULL OR compare_at_price > price`
- CHECK: `cost_price IS NULL OR cost_price >= 0`

**Indexes**:
- `idx_product_variants_product_id` ON `product_id`
- `idx_product_variants_sku` ON `sku` (unique)
- Partial unique: UNIQUE (`product_id`) WHERE `is_default = true` — one default per product

---

### Table: `variant_attribute_values`

**Purpose**: The specific attribute values for each variant (e.g., Size=L, Color=Black).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `variant_id` | UUID | NOT NULL | — | FK → product_variants.id |
| `attribute_id` | UUID | NOT NULL | — | FK → attribute_definitions.id |
| `value` | VARCHAR(255) | NOT NULL | — | e.g., "L", "Black" |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: (`variant_id`, `attribute_id`)
- FK: `variant_id` → `product_variants.id` ON DELETE CASCADE
- FK: `attribute_id` → `attribute_definitions.id` ON DELETE RESTRICT

---

### Table: `product_images`

**Purpose**: Images for products and their variants. Supports separate image sets per variant.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `product_id` | UUID | NOT NULL | — | FK → products.id |
| `variant_id` | UUID | NULL | — | FK → product_variants.id; NULL = product-level image |
| `url` | VARCHAR(1000) | NOT NULL | — | S3/CDN URL |
| `alt_text` | VARCHAR(255) | NULL | — | Accessibility |
| `sort_order` | INTEGER | NOT NULL | 0 | |
| `is_primary` | BOOLEAN | NOT NULL | false | Primary display image |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `product_id` → `products.id` ON DELETE CASCADE
- FK: `variant_id` → `product_variants.id` ON DELETE CASCADE

**Indexes**:
- `idx_product_images_product_id` ON `product_id`
- `idx_product_images_variant_id` ON `variant_id`

---

### Table: `product_specifications`

**Purpose**: Key-value technical specifications for a product (e.g., Screen Size: 6.7 inches).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `product_id` | UUID | NOT NULL | — | FK → products.id |
| `label` | VARCHAR(200) | NOT NULL | — | e.g., "Battery Capacity" |
| `value` | VARCHAR(500) | NOT NULL | — | e.g., "5000 mAh" |
| `sort_order` | INTEGER | NOT NULL | 0 | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `product_id` → `products.id` ON DELETE CASCADE

---

## Domain 5: Inventory

### Table: `inventory`

**Purpose**: Current stock levels per variant. Single-location for MVP. One row per variant.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `variant_id` | UUID | NOT NULL | — | FK → product_variants.id UNIQUE |
| `quantity_on_hand` | INTEGER | NOT NULL | 0 | Physical stock in warehouse |
| `quantity_reserved` | INTEGER | NOT NULL | 0 | Reserved in active carts/orders |
| `reorder_point` | INTEGER | NOT NULL | 0 | Alert threshold |
| `reorder_quantity` | INTEGER | NULL | — | Suggested reorder qty |
| `allow_backorder` | BOOLEAN | NOT NULL | false | Allow orders when OOS |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `variant_id`
- FK: `variant_id` → `product_variants.id` ON DELETE CASCADE
- CHECK: `quantity_on_hand >= 0`
- CHECK: `quantity_reserved >= 0`
- CHECK: `quantity_reserved <= quantity_on_hand` (enforced at app level + DB trigger)

**Computed**: `quantity_available = quantity_on_hand - quantity_reserved` (application-computed; not a generated column to allow complex backorder logic)

**Indexes**:
- `idx_inventory_variant_id` ON `variant_id` (unique)
- `idx_inventory_low_stock` ON `quantity_on_hand` WHERE `quantity_on_hand <= reorder_point`

---

### Table: `inventory_transactions`

**Purpose**: Immutable ledger of all inventory movements. Every quantity change must produce a record.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `variant_id` | UUID | NOT NULL | — | FK → product_variants.id |
| `transaction_type` | VARCHAR(30) | NOT NULL | — | CHECK: see values below |
| `quantity_change` | INTEGER | NOT NULL | — | Positive = increase, negative = decrease |
| `quantity_before` | INTEGER | NOT NULL | — | Snapshot before change |
| `quantity_after` | INTEGER | NOT NULL | — | Snapshot after change |
| `reference_type` | VARCHAR(30) | NULL | — | CHECK: order, return, adjustment, purchase_order |
| `reference_id` | UUID | NULL | — | FK to the source entity (polymorphic) |
| `notes` | TEXT | NULL | — | Required for manual adjustments |
| `created_by` | UUID | NULL | — | FK → users.id |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**transaction_type values**: `receive`, `reserve`, `release`, `fulfill`, `return`, `manual_adjustment`, `writeoff`

**Constraints**:
- PK: `id`
- FK: `variant_id` → `product_variants.id`
- FK: `created_by` → `users.id` ON DELETE SET NULL
- CHECK: `transaction_type IN ('receive','reserve','release','fulfill','return','manual_adjustment','writeoff')`

**Indexes**:
- `idx_inv_tx_variant_id` ON `variant_id`
- `idx_inv_tx_reference` ON (`reference_type`, `reference_id`)
- `idx_inv_tx_created_at` ON `created_at` (for time-series reporting)

**Append-only**: No updates or deletes. Enforced by application and potentially DB trigger.

---

## Domain 6: Customer Engagement

### Table: `wishlists`

**Purpose**: Named collections of products saved by a customer.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `customer_id` | UUID | NOT NULL | — | FK → customers.id |
| `name` | VARCHAR(200) | NOT NULL | 'My Wishlist' | |
| `is_public` | BOOLEAN | NOT NULL | false | Shareable wishlist |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `customer_id` → `customers.id` ON DELETE CASCADE

---

### Table: `wishlist_items`

**Purpose**: Individual product/variant entries in a wishlist.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `wishlist_id` | UUID | NOT NULL | — | FK → wishlists.id |
| `product_id` | UUID | NOT NULL | — | FK → products.id |
| `variant_id` | UUID | NULL | — | FK → product_variants.id |
| `added_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: (`wishlist_id`, `product_id`, `variant_id`)
- FK: `wishlist_id` → `wishlists.id` ON DELETE CASCADE
- FK: `product_id` → `products.id` ON DELETE CASCADE

---

### Table: `recently_viewed_products`

**Purpose**: Tracks the last-viewed product per customer for personalization.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `customer_id` | UUID | NOT NULL | — | FK → customers.id |
| `product_id` | UUID | NOT NULL | — | FK → products.id |
| `variant_id` | UUID | NULL | — | FK → product_variants.id |
| `viewed_at` | TIMESTAMPTZ | NOT NULL | NOW() | Updated on re-view |

**Constraints**:
- PK: `id`
- UNIQUE: (`customer_id`, `product_id`)
- FK: `customer_id` → `customers.id` ON DELETE CASCADE
- FK: `product_id` → `products.id` ON DELETE CASCADE

**Indexes**:
- `idx_recently_viewed_customer` ON (`customer_id`, `viewed_at` DESC)

**Design Note**: On re-view, UPDATE the existing row (set viewed_at = NOW()) rather than INSERT. Keep only last 50 records per customer via application-level cleanup.

---

## Domain 7: Cart

### Table: `carts`

**Purpose**: Shopping cart state. Supports both guest (session-based) and logged-in customer carts.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `customer_id` | UUID | NULL | — | FK → customers.id; NULL for guest |
| `session_id` | VARCHAR(255) | NULL | — | Guest session token |
| `status` | VARCHAR(20) | NOT NULL | 'active' | CHECK: active, abandoned, converted, expired |
| `coupon_id` | UUID | NULL | — | FK → coupons.id |
| `currency` | CHAR(3) | NOT NULL | 'INR' | ISO 4217 |
| `expires_at` | TIMESTAMPTZ | NULL | — | Guest cart expiry |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `customer_id` → `customers.id` ON DELETE SET NULL
- FK: `coupon_id` → `coupons.id` ON DELETE SET NULL
- CHECK: `status IN ('active', 'abandoned', 'converted', 'expired')`
- CHECK: `customer_id IS NOT NULL OR session_id IS NOT NULL`

**Indexes**:
- `idx_carts_customer_id` ON `customer_id` WHERE status = 'active'
- `idx_carts_session_id` ON `session_id` WHERE session_id IS NOT NULL

---

### Table: `cart_items`

**Purpose**: Individual line items in a cart. Price stored at addition time for change-detection.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `cart_id` | UUID | NOT NULL | — | FK → carts.id |
| `product_id` | UUID | NOT NULL | — | FK → products.id |
| `variant_id` | UUID | NOT NULL | — | FK → product_variants.id |
| `quantity` | INTEGER | NOT NULL | — | CHECK: > 0 |
| `unit_price` | NUMERIC(12,2) | NOT NULL | — | Price at time of adding |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: (`cart_id`, `variant_id`)
- FK: `cart_id` → `carts.id` ON DELETE CASCADE
- FK: `product_id` → `products.id`
- FK: `variant_id` → `product_variants.id`
- CHECK: `quantity > 0`
- CHECK: `unit_price > 0`

---

## Domain 8: Orders

### Table: `orders`

**Purpose**: Master order record. Contains snapshots of all pricing, address, and customer data at time of order.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `order_number` | VARCHAR(30) | NOT NULL | — | Human-readable, unique (e.g., ORD-2024-000001) |
| `customer_id` | UUID | NOT NULL | — | FK → customers.id |
| `status` | VARCHAR(30) | NOT NULL | 'pending' | CHECK: see values below |
| `payment_status` | VARCHAR(30) | NOT NULL | 'pending' | CHECK: see values below |
| `fulfillment_status` | VARCHAR(30) | NOT NULL | 'unfulfilled' | CHECK: see values below |
| `currency` | CHAR(3) | NOT NULL | 'INR' | |
| `customer_email` | VARCHAR(255) | NOT NULL | — | SNAPSHOT |
| `customer_phone` | VARCHAR(20) | NULL | — | SNAPSHOT |
| `customer_name` | VARCHAR(200) | NOT NULL | — | SNAPSHOT |
| `shipping_address` | JSONB | NOT NULL | — | SNAPSHOT of full address |
| `billing_address` | JSONB | NULL | — | SNAPSHOT; NULL = same as shipping |
| `subtotal` | NUMERIC(12,2) | NOT NULL | — | Sum of (unit_price * qty) before discounts |
| `discount_amount` | NUMERIC(12,2) | NOT NULL | 0 | Coupon discount |
| `shipping_amount` | NUMERIC(12,2) | NOT NULL | 0 | |
| `tax_amount` | NUMERIC(12,2) | NOT NULL | 0 | |
| `total_amount` | NUMERIC(12,2) | NOT NULL | — | subtotal - discount + shipping + tax |
| `coupon_id` | UUID | NULL | — | FK → coupons.id; nullable |
| `coupon_code` | VARCHAR(50) | NULL | — | SNAPSHOT of coupon code |
| `notes` | TEXT | NULL | — | Customer notes |
| `idempotency_key` | VARCHAR(255) | NULL | — | Prevents duplicate order creation |
| `cancelled_at` | TIMESTAMPTZ | NULL | — | |
| `cancellation_reason` | TEXT | NULL | — | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**status values**: `pending`, `confirmed`, `processing`, `shipped`, `delivered`, `cancelled`, `refunded`, `partially_refunded`
**payment_status values**: `pending`, `paid`, `failed`, `refunded`, `partially_refunded`
**fulfillment_status values**: `unfulfilled`, `partially_fulfilled`, `fulfilled`, `returned`, `partially_returned`

**Constraints**:
- PK: `id`
- UNIQUE: `order_number`
- UNIQUE: `idempotency_key`
- FK: `customer_id` → `customers.id`
- FK: `coupon_id` → `coupons.id` ON DELETE SET NULL
- CHECK: `subtotal >= 0`
- CHECK: `total_amount >= 0`
- CHECK: `total_amount = subtotal - discount_amount + shipping_amount + tax_amount`

**Indexes**:
- `idx_orders_order_number` ON `order_number` (unique)
- `idx_orders_customer_id` ON `customer_id`
- `idx_orders_status` ON `status`
- `idx_orders_payment_status` ON `payment_status`
- `idx_orders_created_at` ON `created_at`
- Composite: `idx_orders_customer_status` ON (`customer_id`, `status`, `created_at` DESC)

---

### Table: `order_items`

**Purpose**: Line items within an order. Fully snapshotted — product/price changes after order creation must NOT affect this record.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `order_id` | UUID | NOT NULL | — | FK → orders.id |
| `product_id` | UUID | NULL | — | FK → products.id; SET NULL if product deleted |
| `variant_id` | UUID | NULL | — | FK → product_variants.id; SET NULL if deleted |
| `vendor_id` | UUID | NULL | — | FK → vendors.id; SET NULL |
| `product_name` | VARCHAR(500) | NOT NULL | — | SNAPSHOT |
| `variant_name` | VARCHAR(255) | NOT NULL | — | SNAPSHOT |
| `sku` | VARCHAR(100) | NOT NULL | — | SNAPSHOT |
| `product_image_url` | VARCHAR(1000) | NULL | — | SNAPSHOT |
| `quantity` | INTEGER | NOT NULL | — | CHECK: > 0 |
| `unit_price` | NUMERIC(12,2) | NOT NULL | — | SNAPSHOT |
| `discount_amount` | NUMERIC(12,2) | NOT NULL | 0 | Item-level discount |
| `tax_rate` | NUMERIC(5,2) | NOT NULL | 0 | SNAPSHOT |
| `tax_amount` | NUMERIC(12,2) | NOT NULL | 0 | SNAPSHOT |
| `total_amount` | NUMERIC(12,2) | NOT NULL | — | (unit_price * qty) - discount + tax |
| `status` | VARCHAR(20) | NOT NULL | 'active' | CHECK: active, cancelled, returned |
| `returned_quantity` | INTEGER | NOT NULL | 0 | For partial returns |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `order_id` → `orders.id` ON DELETE RESTRICT
- FK: `product_id` → `products.id` ON DELETE SET NULL
- FK: `variant_id` → `product_variants.id` ON DELETE SET NULL
- FK: `vendor_id` → `vendors.id` ON DELETE SET NULL
- CHECK: `quantity > 0`
- CHECK: `returned_quantity <= quantity`
- CHECK: `status IN ('active', 'cancelled', 'returned')`

**Indexes**:
- `idx_order_items_order_id` ON `order_id`
- `idx_order_items_product_id` ON `product_id`
- `idx_order_items_variant_id` ON `variant_id`

---

### Table: `order_status_history`

**Purpose**: Immutable audit trail of every order status transition.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `order_id` | UUID | NOT NULL | — | FK → orders.id |
| `status` | VARCHAR(30) | NOT NULL | — | New status |
| `payment_status` | VARCHAR(30) | NULL | — | New payment status if changed |
| `comment` | TEXT | NULL | — | Reason / note |
| `changed_by` | UUID | NULL | — | FK → users.id (NULL = system) |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `order_id` → `orders.id` ON DELETE RESTRICT
- FK: `changed_by` → `users.id` ON DELETE SET NULL

**Indexes**:
- `idx_order_status_history_order_id` ON `order_id`

**Append-only**: No updates or deletes.

---

## Domain 9: Payments

### Table: `payments`

**Purpose**: A payment attempt against an order. One order may have multiple payment records (retry scenario).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `order_id` | UUID | NOT NULL | — | FK → orders.id |
| `provider` | VARCHAR(30) | NOT NULL | — | CHECK: razorpay, stripe, cod, other |
| `provider_order_id` | VARCHAR(255) | NULL | — | External payment session/order ID |
| `amount` | NUMERIC(12,2) | NOT NULL | — | Amount to be collected |
| `currency` | CHAR(3) | NOT NULL | 'INR' | |
| `status` | VARCHAR(20) | NOT NULL | 'pending' | CHECK: pending, processing, completed, failed, cancelled |
| `method` | VARCHAR(30) | NULL | — | CHECK: card, upi, netbanking, wallet, cod, bnpl |
| `idempotency_key` | VARCHAR(255) | NOT NULL | — | Per payment attempt |
| `metadata` | JSONB | NULL | '{}' | Provider-specific non-sensitive data |
| `expires_at` | TIMESTAMPTZ | NULL | — | Payment session expiry |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `idempotency_key`
- FK: `order_id` → `orders.id` ON DELETE RESTRICT
- CHECK: `amount > 0`
- CHECK: `provider IN ('razorpay', 'stripe', 'cod', 'other')`
- CHECK: `status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')`

**Indexes**:
- `idx_payments_order_id` ON `order_id`
- `idx_payments_provider_order_id` ON `provider_order_id` WHERE provider_order_id IS NOT NULL

---

### Table: `payment_transactions`

**Purpose**: Individual transaction events from the payment provider (charge, refund events). Append-only ledger.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `payment_id` | UUID | NOT NULL | — | FK → payments.id |
| `provider_transaction_id` | VARCHAR(255) | NULL | — | External tx reference |
| `type` | VARCHAR(20) | NOT NULL | — | CHECK: charge, refund, partial_refund, chargeback |
| `amount` | NUMERIC(12,2) | NOT NULL | — | |
| `currency` | CHAR(3) | NOT NULL | 'INR' | |
| `status` | VARCHAR(20) | NOT NULL | — | CHECK: success, failed, pending |
| `failure_code` | VARCHAR(100) | NULL | — | Provider error code |
| `failure_message` | TEXT | NULL | — | Provider error message |
| `metadata` | JSONB | NULL | '{}' | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `provider_transaction_id` (when not null, partial unique)
- FK: `payment_id` → `payments.id` ON DELETE RESTRICT
- CHECK: `amount > 0`

**Indexes**:
- `idx_payment_tx_payment_id` ON `payment_id`
- `idx_payment_tx_provider_id` ON `provider_transaction_id` WHERE provider_transaction_id IS NOT NULL

---

### Table: `refunds`

**Purpose**: Refund requests against paid orders. Tracks refund lifecycle independently from payments.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `order_id` | UUID | NOT NULL | — | FK → orders.id |
| `payment_id` | UUID | NOT NULL | — | FK → payments.id |
| `initiated_by` | UUID | NOT NULL | — | FK → users.id |
| `amount` | NUMERIC(12,2) | NOT NULL | — | |
| `reason` | TEXT | NOT NULL | — | |
| `type` | VARCHAR(20) | NOT NULL | — | CHECK: full, partial, item |
| `status` | VARCHAR(20) | NOT NULL | 'pending' | CHECK: pending, processing, completed, failed |
| `provider_refund_id` | VARCHAR(255) | NULL | — | External refund ID |
| `failure_reason` | TEXT | NULL | — | |
| `completed_at` | TIMESTAMPTZ | NULL | — | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `order_id` → `orders.id`
- FK: `payment_id` → `payments.id`
- FK: `initiated_by` → `users.id`
- CHECK: `amount > 0`
- CHECK: `type IN ('full', 'partial', 'item')`
- CHECK: `status IN ('pending', 'processing', 'completed', 'failed')`

**Indexes**:
- `idx_refunds_order_id` ON `order_id`
- `idx_refunds_payment_id` ON `payment_id`

---

## Domain 10: Shipping

### Table: `shipments`

**Purpose**: Shipment records for orders. One order can have multiple shipments (split shipment).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `order_id` | UUID | NOT NULL | — | FK → orders.id |
| `provider` | VARCHAR(100) | NULL | — | e.g., "delhivery", "bluedart" |
| `tracking_number` | VARCHAR(255) | NULL | — | Courier tracking number |
| `tracking_url` | VARCHAR(1000) | NULL | — | Public tracking link |
| `status` | VARCHAR(30) | NOT NULL | 'pending' | CHECK: see values below |
| `shipping_address` | JSONB | NOT NULL | — | SNAPSHOT of delivery address |
| `weight_grams` | INTEGER | NULL | — | Total shipment weight |
| `package_dimensions` | JSONB | NULL | — | {length, width, height, unit} |
| `estimated_delivery` | DATE | NULL | — | Advisory EDD |
| `shipped_at` | TIMESTAMPTZ | NULL | — | |
| `delivered_at` | TIMESTAMPTZ | NULL | — | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**status values**: `pending`, `ready_to_ship`, `picked_up`, `in_transit`, `out_for_delivery`, `delivered`, `delivery_failed`, `returned`

**Constraints**:
- PK: `id`
- FK: `order_id` → `orders.id` ON DELETE RESTRICT

**Indexes**:
- `idx_shipments_order_id` ON `order_id`
- `idx_shipments_tracking_number` ON `tracking_number` WHERE tracking_number IS NOT NULL

---

### Table: `shipment_items`

**Purpose**: Maps which order_items are in which shipment (for split-shipment support).

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `shipment_id` | UUID | NOT NULL | — | FK → shipments.id |
| `order_item_id` | UUID | NOT NULL | — | FK → order_items.id |
| `quantity` | INTEGER | NOT NULL | — | Quantity in this shipment |

**Constraints**:
- PK: `id`
- UNIQUE: (`shipment_id`, `order_item_id`)
- FK: `shipment_id` → `shipments.id` ON DELETE CASCADE
- FK: `order_item_id` → `order_items.id`
- CHECK: `quantity > 0`

---

### Table: `shipment_tracking_events`

**Purpose**: Append-only log of shipment status updates / tracking milestones.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `shipment_id` | UUID | NOT NULL | — | FK → shipments.id |
| `status` | VARCHAR(30) | NOT NULL | — | Milestone status |
| `description` | TEXT | NULL | — | Human-readable event description |
| `location` | VARCHAR(255) | NULL | — | City/hub where event occurred |
| `occurred_at` | TIMESTAMPTZ | NOT NULL | — | When the event happened (may be past) |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | When we recorded it |

**Constraints**:
- PK: `id`
- FK: `shipment_id` → `shipments.id` ON DELETE CASCADE

**Indexes**:
- `idx_shipment_tracking_shipment_id` ON (`shipment_id`, `occurred_at` DESC)

---

## Domain 11: Promotions

### Table: `coupons`

**Purpose**: Discount coupons with flexible targeting and usage constraints.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `code` | VARCHAR(50) | NOT NULL | — | Uppercase, unique |
| `description` | TEXT | NULL | — | Internal description |
| `discount_type` | VARCHAR(20) | NOT NULL | — | CHECK: percentage, fixed |
| `discount_value` | NUMERIC(10,2) | NOT NULL | — | % or flat amount |
| `max_discount_amount` | NUMERIC(10,2) | NULL | — | Cap for percentage discounts |
| `min_order_amount` | NUMERIC(10,2) | NULL | — | Minimum cart value |
| `applicable_to` | VARCHAR(20) | NOT NULL | 'all' | CHECK: all, categories, brands, products |
| `usage_limit` | INTEGER | NULL | — | Total max redemptions; NULL = unlimited |
| `usage_per_customer` | INTEGER | NULL | 1 | Max per customer; NULL = unlimited |
| `current_usage_count` | INTEGER | NOT NULL | 0 | Incremented on order creation |
| `starts_at` | TIMESTAMPTZ | NOT NULL | — | |
| `expires_at` | TIMESTAMPTZ | NULL | — | NULL = no expiry |
| `is_active` | BOOLEAN | NOT NULL | true | |
| `created_by` | UUID | NOT NULL | — | FK → users.id |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `code`
- FK: `created_by` → `users.id`
- CHECK: `discount_type IN ('percentage', 'fixed')`
- CHECK: `discount_value > 0`
- CHECK: `applicable_to IN ('all', 'categories', 'brands', 'products')`
- CHECK: `discount_type = 'fixed' OR (discount_value <= 100)`

**Indexes**:
- `idx_coupons_code` ON `code` (unique)
- `idx_coupons_active` ON `is_active`, `starts_at`, `expires_at`

---

### Table: `coupon_applicable_items`

**Purpose**: Specifies which categories/brands/products a coupon applies to (when applicable_to ≠ 'all').

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `coupon_id` | UUID | NOT NULL | — | FK → coupons.id |
| `item_type` | VARCHAR(20) | NOT NULL | — | CHECK: product, category, brand |
| `item_id` | UUID | NOT NULL | — | ID of the product/category/brand |

**Constraints**:
- PK: `id`
- UNIQUE: (`coupon_id`, `item_type`, `item_id`)
- FK: `coupon_id` → `coupons.id` ON DELETE CASCADE

---

### Table: `coupon_usages`

**Purpose**: Records each coupon redemption, enabling per-customer usage tracking and rollback on cancellation.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `coupon_id` | UUID | NOT NULL | — | FK → coupons.id |
| `order_id` | UUID | NOT NULL | — | FK → orders.id |
| `customer_id` | UUID | NOT NULL | — | FK → customers.id |
| `discount_amount` | NUMERIC(10,2) | NOT NULL | — | Actual discount applied |
| `used_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: (`coupon_id`, `order_id`)
- FK: `coupon_id` → `coupons.id`
- FK: `order_id` → `orders.id`
- FK: `customer_id` → `customers.id`

**Indexes**:
- `idx_coupon_usages_coupon_customer` ON (`coupon_id`, `customer_id`)

---

## Domain 12: Reviews

### Table: `product_reviews`

**Purpose**: Customer product ratings and review text. One review per customer per product.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `product_id` | UUID | NOT NULL | — | FK → products.id |
| `customer_id` | UUID | NOT NULL | — | FK → customers.id |
| `order_item_id` | UUID | NULL | — | FK → order_items.id; for verified purchase |
| `rating` | SMALLINT | NOT NULL | — | CHECK: 1–5 |
| `title` | VARCHAR(255) | NULL | — | |
| `body` | TEXT | NULL | — | Review text |
| `is_verified_purchase` | BOOLEAN | NOT NULL | false | |
| `status` | VARCHAR(20) | NOT NULL | 'pending' | CHECK: pending, approved, rejected |
| `helpful_count` | INTEGER | NOT NULL | 0 | Upvote count |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `deleted_at` | TIMESTAMPTZ | NULL | — | Soft delete |

**Constraints**:
- PK: `id`
- UNIQUE: (`product_id`, `customer_id`) — one review per customer per product
- FK: `product_id` → `products.id` ON DELETE CASCADE
- FK: `customer_id` → `customers.id`
- FK: `order_item_id` → `order_items.id` ON DELETE SET NULL
- CHECK: `rating BETWEEN 1 AND 5`
- CHECK: `status IN ('pending', 'approved', 'rejected')`

**Indexes**:
- `idx_reviews_product_id` ON (`product_id`, `status`) WHERE `deleted_at IS NULL`
- `idx_reviews_customer_id` ON `customer_id`

---

### Table: `review_images`

**Purpose**: Images attached to a product review.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `review_id` | UUID | NOT NULL | — | FK → product_reviews.id |
| `url` | VARCHAR(1000) | NOT NULL | — | S3/CDN URL |
| `sort_order` | INTEGER | NOT NULL | 0 | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `review_id` → `product_reviews.id` ON DELETE CASCADE

---

## Domain 13: Notifications

### Table: `device_tokens`

**Purpose**: FCM/APNs device tokens for push notifications.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `user_id` | UUID | NOT NULL | — | FK → users.id |
| `token` | VARCHAR(500) | NOT NULL | — | FCM or APNs token |
| `platform` | VARCHAR(10) | NOT NULL | — | CHECK: android, ios |
| `is_active` | BOOLEAN | NOT NULL | true | |
| `last_used_at` | TIMESTAMPTZ | NULL | — | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: `token`
- FK: `user_id` → `users.id` ON DELETE CASCADE
- CHECK: `platform IN ('android', 'ios')`

---

### Table: `notifications`

**Purpose**: Per-user notification records. Used for in-app notification center and tracking delivery status.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `user_id` | UUID | NOT NULL | — | FK → users.id |
| `type` | VARCHAR(50) | NOT NULL | — | e.g., order_placed, payment_success |
| `channel` | VARCHAR(20) | NOT NULL | — | CHECK: push, email, sms, in_app |
| `title` | VARCHAR(255) | NOT NULL | — | |
| `body` | TEXT | NOT NULL | — | |
| `data` | JSONB | NULL | '{}' | Deep link data, entity IDs |
| `is_read` | BOOLEAN | NOT NULL | false | |
| `read_at` | TIMESTAMPTZ | NULL | — | |
| `sent_at` | TIMESTAMPTZ | NULL | — | NULL = not yet sent |
| `failed_at` | TIMESTAMPTZ | NULL | — | NULL = not failed |
| `failure_reason` | TEXT | NULL | — | |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `user_id` → `users.id` ON DELETE CASCADE

**Indexes**:
- `idx_notifications_user_id` ON (`user_id`, `created_at` DESC)
- `idx_notifications_unread` ON `user_id` WHERE `is_read = false`

---

### Table: `notification_preferences`

**Purpose**: User opt-in/out preferences per notification type and channel.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | UUID | NOT NULL | gen_random_uuid() | PK |
| `user_id` | UUID | NOT NULL | — | FK → users.id |
| `notification_type` | VARCHAR(50) | NOT NULL | — | e.g., order_placed |
| `push_enabled` | BOOLEAN | NOT NULL | true | |
| `email_enabled` | BOOLEAN | NOT NULL | true | |
| `sms_enabled` | BOOLEAN | NOT NULL | false | |
| `updated_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- UNIQUE: (`user_id`, `notification_type`)
- FK: `user_id` → `users.id` ON DELETE CASCADE

---

## Domain 14: Audit

### Table: `audit_logs`

**Purpose**: Immutable record of all significant write operations. Append-only. Never updated or deleted.

| Column | Type | Nullable | Default | Notes |
|--------|------|----------|---------|-------|
| `id` | BIGSERIAL | NOT NULL | — | PK (integer for high-volume insert performance) |
| `user_id` | UUID | NULL | — | Actor; NULL = system/background |
| `action` | VARCHAR(30) | NOT NULL | — | CHECK: create, update, delete, login, logout, permission_change |
| `resource_type` | VARCHAR(100) | NOT NULL | — | e.g., "Product", "Order", "User" |
| `resource_id` | UUID | NOT NULL | — | |
| `old_values` | JSONB | NULL | — | Previous state (for updates) |
| `new_values` | JSONB | NULL | — | New state |
| `ip_address` | INET | NULL | — | |
| `user_agent` | VARCHAR(500) | NULL | — | |
| `request_id` | VARCHAR(100) | NULL | — | Correlation ID from request |
| `created_at` | TIMESTAMPTZ | NOT NULL | NOW() | |

**Constraints**:
- PK: `id`
- FK: `user_id` → `users.id` ON DELETE SET NULL

**Indexes**:
- `idx_audit_logs_user_id` ON `user_id`
- `idx_audit_logs_resource` ON (`resource_type`, `resource_id`)
- `idx_audit_logs_created_at` ON `created_at` (for time-range queries)

**Partitioning Note**: This table will grow large. Plan for range partitioning by `created_at` (monthly partitions) after initial deployment.

---

## Index Strategy Summary

### Query Patterns and Index Coverage

| Query Pattern | Table | Index |
|---------------|-------|-------|
| Customer login by email | users | idx_users_email |
| Active cart by customer | carts | idx_carts_customer_id (partial: status=active) |
| Products by category | products | idx_products_active_category |
| Full-text product search | products | idx_products_search_vector (GIN) |
| Tag search | products | idx_products_tags (GIN) |
| Order list by customer | orders | idx_orders_customer_status |
| Orders by status (admin) | orders | idx_orders_status |
| Payment by provider order | payments | idx_payments_provider_order_id |
| Inventory check by variant | inventory | idx_inventory_variant_id |
| Coupon lookup by code | coupons | idx_coupons_code |
| Shipment by tracking | shipments | idx_shipments_tracking_number |
| Review by product | product_reviews | idx_reviews_product_id |
| Unread notifications | notifications | idx_notifications_unread |
| Audit by resource | audit_logs | idx_audit_logs_resource |

---

## Financial Data Rules

All monetary columns use `NUMERIC(12,2)`:
- Supports values up to 9,999,999,999.99 (sufficient for INR amounts)
- Rounding: ROUND_HALF_UP at application layer
- No FLOAT, REAL, or DOUBLE PRECISION for any monetary column
- Tax calculations done at item level before aggregation

---

## Soft Delete Strategy

Tables with `deleted_at TIMESTAMPTZ`:
- `users`
- `vendors`
- `categories`
- `brands`
- `products`
- `product_reviews`

Soft delete approach:
1. Set `deleted_at = NOW()`
2. All queries add `WHERE deleted_at IS NULL` (enforced by repository layer)
3. Partial indexes (WHERE deleted_at IS NULL) on frequently queried columns

---

## Table Count Summary

| Domain | Tables |
|--------|--------|
| Identity & Access | users, roles, permissions, role_permissions, user_roles, refresh_tokens, otp_verifications |
| Customer | customers, customer_addresses |
| Vendor | vendors, vendor_users |
| Product Catalog | categories, brands, attribute_groups, attribute_definitions, products, product_variants, variant_attribute_values, product_images, product_specifications |
| Inventory | inventory, inventory_transactions |
| Engagement | wishlists, wishlist_items, recently_viewed_products |
| Cart | carts, cart_items |
| Orders | orders, order_items, order_status_history |
| Payments | payments, payment_transactions, refunds |
| Shipping | shipments, shipment_items, shipment_tracking_events |
| Promotions | coupons, coupon_applicable_items, coupon_usages |
| Reviews | product_reviews, review_images |
| Notifications | device_tokens, notifications, notification_preferences |
| Audit | audit_logs |
| **TOTAL** | **44 tables** |
