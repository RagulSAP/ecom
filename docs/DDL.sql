-- ============================================================
-- Enterprise E-Commerce Platform — PostgreSQL DDL
-- Compatible with: dbdiagram.io SQL import, PostgreSQL 16
-- Generated: 2026-09-27
-- ============================================================

-- Extensions
-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- for gen_random_uuid() on PG < 13
-- CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- for trigram search indexes

-- ============================================================
-- DOMAIN 1: IDENTITY & ACCESS MANAGEMENT
-- ============================================================

CREATE TABLE users (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    email           VARCHAR(255)    NOT NULL,
    phone           VARCHAR(20)     NULL,
    password_hash   VARCHAR(255)    NOT NULL,
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    is_verified     BOOLEAN         NOT NULL DEFAULT FALSE,
    is_staff        BOOLEAN         NOT NULL DEFAULT FALSE,
    last_login_at   TIMESTAMPTZ     NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ     NULL,
    CONSTRAINT pk_users PRIMARY KEY (id),
    CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE TABLE roles (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    name            VARCHAR(100)    NOT NULL,
    description     TEXT            NULL,
    is_system       BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_roles PRIMARY KEY (id),
    CONSTRAINT uq_roles_name UNIQUE (name)
);

CREATE TABLE permissions (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    code            VARCHAR(100)    NOT NULL,
    module          VARCHAR(50)     NOT NULL,
    description     TEXT            NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_permissions PRIMARY KEY (id),
    CONSTRAINT uq_permissions_code UNIQUE (code)
);

CREATE TABLE role_permissions (
    role_id         UUID            NOT NULL,
    permission_id   UUID            NOT NULL,
    CONSTRAINT pk_role_permissions PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE CASCADE,
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE CASCADE
);

CREATE TABLE user_roles (
    user_id         UUID            NOT NULL,
    role_id         UUID            NOT NULL,
    granted_by      UUID            NULL,
    granted_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE RESTRICT,
    CONSTRAINT fk_ur_granted_by FOREIGN KEY (granted_by) REFERENCES users (id) ON DELETE SET NULL
);

CREATE TABLE refresh_tokens (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    token_hash      VARCHAR(255)    NOT NULL,
    expires_at      TIMESTAMPTZ     NOT NULL,
    revoked_at      TIMESTAMPTZ     NULL,
    ip_address      VARCHAR(45)     NULL,
    user_agent      VARCHAR(500)    NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_refresh_tokens PRIMARY KEY (id),
    CONSTRAINT uq_refresh_tokens_hash UNIQUE (token_hash),
    CONSTRAINT fk_rt_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE TABLE otp_verifications (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID            NULL,
    identifier      VARCHAR(255)    NOT NULL,
    purpose         VARCHAR(50)     NOT NULL,
    otp_hash        VARCHAR(255)    NOT NULL,
    expires_at      TIMESTAMPTZ     NOT NULL,
    verified_at     TIMESTAMPTZ     NULL,
    attempts        SMALLINT        NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_otp_verifications PRIMARY KEY (id),
    CONSTRAINT fk_otp_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_otp_purpose CHECK (purpose IN ('email_verification', 'phone_verification', 'password_reset')),
    CONSTRAINT chk_otp_attempts CHECK (attempts <= 3)
);

-- ============================================================
-- DOMAIN 2: CUSTOMER
-- ============================================================

CREATE TABLE customers (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    display_name    VARCHAR(200)    NULL,
    avatar_url      VARCHAR(500)    NULL,
    date_of_birth   DATE            NULL,
    gender          VARCHAR(20)     NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_customers PRIMARY KEY (id),
    CONSTRAINT uq_customers_user_id UNIQUE (user_id),
    CONSTRAINT fk_customers_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_customers_gender CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say'))
);

CREATE TABLE customer_addresses (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    customer_id     UUID            NOT NULL,
    label           VARCHAR(50)     NULL,
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    phone           VARCHAR(20)     NOT NULL,
    address_line1   VARCHAR(255)    NOT NULL,
    address_line2   VARCHAR(255)    NULL,
    city            VARCHAR(100)    NOT NULL,
    state           VARCHAR(100)    NOT NULL,
    postal_code     VARCHAR(20)     NOT NULL,
    country         CHAR(2)         NOT NULL DEFAULT 'IN',
    is_default      BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_customer_addresses PRIMARY KEY (id),
    CONSTRAINT fk_ca_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
);

-- ============================================================
-- DOMAIN 3: VENDOR (Multi-Vendor Readiness)
-- ============================================================

CREATE TABLE vendors (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    name            VARCHAR(255)    NOT NULL,
    slug            VARCHAR(255)    NOT NULL,
    description     TEXT            NULL,
    email           VARCHAR(255)    NOT NULL,
    phone           VARCHAR(20)     NULL,
    logo_url        VARCHAR(500)    NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'pending',
    commission_rate NUMERIC(5,2)    NOT NULL DEFAULT 0.00,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ     NULL,
    CONSTRAINT pk_vendors PRIMARY KEY (id),
    CONSTRAINT uq_vendors_slug UNIQUE (slug),
    CONSTRAINT uq_vendors_email UNIQUE (email),
    CONSTRAINT chk_vendors_status CHECK (status IN ('pending', 'active', 'suspended', 'deactivated')),
    CONSTRAINT chk_vendors_commission CHECK (commission_rate >= 0 AND commission_rate <= 100)
);

CREATE TABLE vendor_users (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    vendor_id       UUID            NOT NULL,
    user_id         UUID            NOT NULL,
    vendor_role     VARCHAR(30)     NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_vendor_users PRIMARY KEY (id),
    CONSTRAINT uq_vendor_users UNIQUE (vendor_id, user_id),
    CONSTRAINT fk_vu_vendor FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE CASCADE,
    CONSTRAINT fk_vu_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_vu_role CHECK (vendor_role IN ('owner', 'admin', 'staff'))
);

-- ============================================================
-- DOMAIN 4: PRODUCT CATALOG
-- ============================================================

CREATE TABLE attribute_groups (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    name            VARCHAR(100)    NOT NULL,
    display_order   INTEGER         NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_attribute_groups PRIMARY KEY (id),
    CONSTRAINT uq_attribute_groups_name UNIQUE (name)
);

CREATE TABLE attribute_definitions (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    group_id            UUID            NULL,
    name                VARCHAR(100)    NOT NULL,
    code                VARCHAR(100)    NOT NULL,
    input_type          VARCHAR(30)     NOT NULL DEFAULT 'select',
    unit                VARCHAR(20)     NULL,
    is_filterable       BOOLEAN         NOT NULL DEFAULT FALSE,
    is_variant_attribute BOOLEAN        NOT NULL DEFAULT FALSE,
    display_order       INTEGER         NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_attribute_definitions PRIMARY KEY (id),
    CONSTRAINT uq_attribute_definitions_code UNIQUE (code),
    CONSTRAINT fk_ad_group FOREIGN KEY (group_id) REFERENCES attribute_groups (id) ON DELETE SET NULL,
    CONSTRAINT chk_ad_input_type CHECK (input_type IN ('select', 'text', 'number', 'boolean'))
);

CREATE TABLE categories (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    parent_id           UUID            NULL,
    name                VARCHAR(200)    NOT NULL,
    slug                VARCHAR(255)    NOT NULL,
    description         TEXT            NULL,
    image_url           VARCHAR(500)    NULL,
    display_order       INTEGER         NOT NULL DEFAULT 0,
    level               SMALLINT        NOT NULL DEFAULT 0,
    path                VARCHAR(1000)   NOT NULL DEFAULT '',
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    meta_title          VARCHAR(255)    NULL,
    meta_description    TEXT            NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ     NULL,
    CONSTRAINT pk_categories PRIMARY KEY (id),
    CONSTRAINT uq_categories_slug UNIQUE (slug),
    CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories (id) ON DELETE RESTRICT
);

CREATE TABLE brands (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    name            VARCHAR(200)    NOT NULL,
    slug            VARCHAR(255)    NOT NULL,
    description     TEXT            NULL,
    logo_url        VARCHAR(500)    NULL,
    website_url     VARCHAR(500)    NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ     NULL,
    CONSTRAINT pk_brands PRIMARY KEY (id),
    CONSTRAINT uq_brands_slug UNIQUE (slug)
);

CREATE TABLE products (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    vendor_id           UUID            NULL,
    category_id         UUID            NOT NULL,
    brand_id            UUID            NULL,
    name                VARCHAR(500)    NOT NULL,
    slug                VARCHAR(600)    NOT NULL,
    short_description   TEXT            NULL,
    description         TEXT            NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'draft',
    is_featured         BOOLEAN         NOT NULL DEFAULT FALSE,
    meta_title          VARCHAR(255)    NULL,
    meta_description    TEXT            NULL,
    tags                TEXT            NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ     NULL,
    CONSTRAINT pk_products PRIMARY KEY (id),
    CONSTRAINT uq_products_slug UNIQUE (slug),
    CONSTRAINT fk_products_vendor FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE SET NULL,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE RESTRICT,
    CONSTRAINT fk_products_brand FOREIGN KEY (brand_id) REFERENCES brands (id) ON DELETE SET NULL,
    CONSTRAINT chk_products_status CHECK (status IN ('draft', 'active', 'inactive', 'archived'))
);

CREATE TABLE product_variants (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    product_id          UUID            NOT NULL,
    sku                 VARCHAR(100)    NOT NULL,
    name                VARCHAR(255)    NOT NULL,
    price               NUMERIC(12,2)   NOT NULL,
    compare_at_price    NUMERIC(12,2)   NULL,
    cost_price          NUMERIC(12,2)   NULL,
    weight_grams        INTEGER         NULL,
    is_default          BOOLEAN         NOT NULL DEFAULT FALSE,
    is_active           BOOLEAN         NOT NULL DEFAULT TRUE,
    sort_order          INTEGER         NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_product_variants PRIMARY KEY (id),
    CONSTRAINT uq_product_variants_sku UNIQUE (sku),
    CONSTRAINT fk_pv_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
    CONSTRAINT chk_pv_price CHECK (price > 0),
    CONSTRAINT chk_pv_compare_price CHECK (compare_at_price IS NULL OR compare_at_price > price),
    CONSTRAINT chk_pv_cost CHECK (cost_price IS NULL OR cost_price >= 0)
);

CREATE TABLE variant_attribute_values (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    variant_id      UUID            NOT NULL,
    attribute_id    UUID            NOT NULL,
    value           VARCHAR(255)    NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_variant_attribute_values PRIMARY KEY (id),
    CONSTRAINT uq_vav UNIQUE (variant_id, attribute_id),
    CONSTRAINT fk_vav_variant FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE CASCADE,
    CONSTRAINT fk_vav_attribute FOREIGN KEY (attribute_id) REFERENCES attribute_definitions (id) ON DELETE RESTRICT
);

CREATE TABLE product_images (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    product_id      UUID            NOT NULL,
    variant_id      UUID            NULL,
    url             VARCHAR(1000)   NOT NULL,
    alt_text        VARCHAR(255)    NULL,
    sort_order      INTEGER         NOT NULL DEFAULT 0,
    is_primary      BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_product_images PRIMARY KEY (id),
    CONSTRAINT fk_pi_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
    CONSTRAINT fk_pi_variant FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE CASCADE
);

CREATE TABLE product_specifications (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    product_id      UUID            NOT NULL,
    label           VARCHAR(200)    NOT NULL,
    value           VARCHAR(500)    NOT NULL,
    sort_order      INTEGER         NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_product_specifications PRIMARY KEY (id),
    CONSTRAINT fk_ps_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE
);

-- ============================================================
-- DOMAIN 5: INVENTORY
-- ============================================================

CREATE TABLE inventory (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    variant_id          UUID            NOT NULL,
    quantity_on_hand    INTEGER         NOT NULL DEFAULT 0,
    quantity_reserved   INTEGER         NOT NULL DEFAULT 0,
    reorder_point       INTEGER         NOT NULL DEFAULT 0,
    reorder_quantity    INTEGER         NULL,
    allow_backorder     BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_inventory PRIMARY KEY (id),
    CONSTRAINT uq_inventory_variant UNIQUE (variant_id),
    CONSTRAINT fk_inventory_variant FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE CASCADE,
    CONSTRAINT chk_inventory_on_hand CHECK (quantity_on_hand >= 0),
    CONSTRAINT chk_inventory_reserved CHECK (quantity_reserved >= 0)
);

CREATE TABLE inventory_transactions (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    variant_id          UUID            NOT NULL,
    transaction_type    VARCHAR(30)     NOT NULL,
    quantity_change     INTEGER         NOT NULL,
    quantity_before     INTEGER         NOT NULL,
    quantity_after      INTEGER         NOT NULL,
    reference_type      VARCHAR(30)     NULL,
    reference_id        UUID            NULL,
    notes               TEXT            NULL,
    created_by          UUID            NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_inventory_transactions PRIMARY KEY (id),
    CONSTRAINT fk_it_variant FOREIGN KEY (variant_id) REFERENCES product_variants (id),
    CONSTRAINT fk_it_created_by FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT chk_it_type CHECK (transaction_type IN ('receive','reserve','release','fulfill','return','manual_adjustment','writeoff'))
);

-- ============================================================
-- DOMAIN 6: CUSTOMER ENGAGEMENT
-- ============================================================

CREATE TABLE wishlists (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    customer_id     UUID            NOT NULL,
    name            VARCHAR(200)    NOT NULL DEFAULT 'My Wishlist',
    is_public       BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_wishlists PRIMARY KEY (id),
    CONSTRAINT fk_wishlists_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE
);

CREATE TABLE wishlist_items (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    wishlist_id     UUID            NOT NULL,
    product_id      UUID            NOT NULL,
    variant_id      UUID            NULL,
    added_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_wishlist_items PRIMARY KEY (id),
    CONSTRAINT uq_wishlist_items UNIQUE (wishlist_id, product_id, variant_id),
    CONSTRAINT fk_wi_wishlist FOREIGN KEY (wishlist_id) REFERENCES wishlists (id) ON DELETE CASCADE,
    CONSTRAINT fk_wi_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
    CONSTRAINT fk_wi_variant FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE CASCADE
);

CREATE TABLE recently_viewed_products (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    customer_id     UUID            NOT NULL,
    product_id      UUID            NOT NULL,
    variant_id      UUID            NULL,
    viewed_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_recently_viewed PRIMARY KEY (id),
    CONSTRAINT uq_recently_viewed UNIQUE (customer_id, product_id),
    CONSTRAINT fk_rv_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE CASCADE,
    CONSTRAINT fk_rv_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
    CONSTRAINT fk_rv_variant FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE SET NULL
);

-- ============================================================
-- DOMAIN 11: PROMOTIONS (defined before cart/orders — referenced by both)
-- ============================================================

CREATE TABLE coupons (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    code                    VARCHAR(50)     NOT NULL,
    description             TEXT            NULL,
    discount_type           VARCHAR(20)     NOT NULL,
    discount_value          NUMERIC(10,2)   NOT NULL,
    max_discount_amount     NUMERIC(10,2)   NULL,
    min_order_amount        NUMERIC(10,2)   NULL,
    applicable_to           VARCHAR(20)     NOT NULL DEFAULT 'all',
    usage_limit             INTEGER         NULL,
    usage_per_customer      INTEGER         NULL DEFAULT 1,
    current_usage_count     INTEGER         NOT NULL DEFAULT 0,
    starts_at               TIMESTAMPTZ     NOT NULL,
    expires_at              TIMESTAMPTZ     NULL,
    is_active               BOOLEAN         NOT NULL DEFAULT TRUE,
    created_by              UUID            NOT NULL,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_coupons PRIMARY KEY (id),
    CONSTRAINT uq_coupons_code UNIQUE (code),
    CONSTRAINT fk_coupons_created_by FOREIGN KEY (created_by) REFERENCES users (id),
    CONSTRAINT chk_coupons_type CHECK (discount_type IN ('percentage', 'fixed')),
    CONSTRAINT chk_coupons_value CHECK (discount_value > 0),
    CONSTRAINT chk_coupons_applicable CHECK (applicable_to IN ('all', 'categories', 'brands', 'products'))
);

CREATE TABLE coupon_applicable_items (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    coupon_id       UUID            NOT NULL,
    item_type       VARCHAR(20)     NOT NULL,
    item_id         UUID            NOT NULL,
    CONSTRAINT pk_coupon_applicable_items PRIMARY KEY (id),
    CONSTRAINT uq_cai UNIQUE (coupon_id, item_type, item_id),
    CONSTRAINT fk_cai_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (id) ON DELETE CASCADE,
    CONSTRAINT chk_cai_item_type CHECK (item_type IN ('product', 'category', 'brand'))
);

-- ============================================================
-- DOMAIN 7: CART
-- ============================================================

CREATE TABLE carts (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    customer_id     UUID            NULL,
    session_id      VARCHAR(255)    NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'active',
    coupon_id       UUID            NULL,
    currency        CHAR(3)         NOT NULL DEFAULT 'INR',
    expires_at      TIMESTAMPTZ     NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_carts PRIMARY KEY (id),
    CONSTRAINT fk_carts_customer FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL,
    CONSTRAINT fk_carts_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (id) ON DELETE SET NULL,
    CONSTRAINT chk_carts_status CHECK (status IN ('active', 'abandoned', 'converted', 'expired')),
    CONSTRAINT chk_carts_identity CHECK (customer_id IS NOT NULL OR session_id IS NOT NULL)
);

CREATE TABLE cart_items (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    cart_id         UUID            NOT NULL,
    product_id      UUID            NOT NULL,
    variant_id      UUID            NOT NULL,
    quantity        INTEGER         NOT NULL,
    unit_price      NUMERIC(12,2)   NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_cart_items PRIMARY KEY (id),
    CONSTRAINT uq_cart_items UNIQUE (cart_id, variant_id),
    CONSTRAINT fk_ci_cart FOREIGN KEY (cart_id) REFERENCES carts (id) ON DELETE CASCADE,
    CONSTRAINT fk_ci_product FOREIGN KEY (product_id) REFERENCES products (id),
    CONSTRAINT fk_ci_variant FOREIGN KEY (variant_id) REFERENCES product_variants (id),
    CONSTRAINT chk_ci_quantity CHECK (quantity > 0),
    CONSTRAINT chk_ci_price CHECK (unit_price > 0)
);

-- ============================================================
-- DOMAIN 8: ORDERS
-- ============================================================

CREATE TABLE orders (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    order_number        VARCHAR(30)     NOT NULL,
    customer_id         UUID            NOT NULL,
    status              VARCHAR(30)     NOT NULL DEFAULT 'pending',
    payment_status      VARCHAR(30)     NOT NULL DEFAULT 'pending',
    fulfillment_status  VARCHAR(30)     NOT NULL DEFAULT 'unfulfilled',
    currency            CHAR(3)         NOT NULL DEFAULT 'INR',
    customer_email      VARCHAR(255)    NOT NULL,
    customer_phone      VARCHAR(20)     NULL,
    customer_name       VARCHAR(200)    NOT NULL,
    shipping_address    TEXT            NOT NULL,
    billing_address     TEXT            NULL,
    subtotal            NUMERIC(12,2)   NOT NULL,
    discount_amount     NUMERIC(12,2)   NOT NULL DEFAULT 0,
    shipping_amount     NUMERIC(12,2)   NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(12,2)   NOT NULL DEFAULT 0,
    total_amount        NUMERIC(12,2)   NOT NULL,
    coupon_id           UUID            NULL,
    coupon_code         VARCHAR(50)     NULL,
    notes               TEXT            NULL,
    idempotency_key     VARCHAR(255)    NULL,
    cancelled_at        TIMESTAMPTZ     NULL,
    cancellation_reason TEXT            NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_orders PRIMARY KEY (id),
    CONSTRAINT uq_orders_number UNIQUE (order_number),
    CONSTRAINT uq_orders_idempotency UNIQUE (idempotency_key),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (id),
    CONSTRAINT fk_orders_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (id) ON DELETE SET NULL,
    CONSTRAINT chk_orders_status CHECK (status IN ('pending','confirmed','processing','shipped','delivered','cancelled','refunded','partially_refunded')),
    CONSTRAINT chk_orders_payment_status CHECK (payment_status IN ('pending','paid','failed','refunded','partially_refunded')),
    CONSTRAINT chk_orders_fulfillment CHECK (fulfillment_status IN ('unfulfilled','partially_fulfilled','fulfilled','returned','partially_returned')),
    CONSTRAINT chk_orders_subtotal CHECK (subtotal >= 0),
    CONSTRAINT chk_orders_total CHECK (total_amount >= 0)
);

CREATE TABLE order_items (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    order_id            UUID            NOT NULL,
    product_id          UUID            NULL,
    variant_id          UUID            NULL,
    vendor_id           UUID            NULL,
    product_name        VARCHAR(500)    NOT NULL,
    variant_name        VARCHAR(255)    NOT NULL,
    sku                 VARCHAR(100)    NOT NULL,
    product_image_url   VARCHAR(1000)   NULL,
    quantity            INTEGER         NOT NULL,
    unit_price          NUMERIC(12,2)   NOT NULL,
    discount_amount     NUMERIC(12,2)   NOT NULL DEFAULT 0,
    tax_rate            NUMERIC(5,2)    NOT NULL DEFAULT 0,
    tax_amount          NUMERIC(12,2)   NOT NULL DEFAULT 0,
    total_amount        NUMERIC(12,2)   NOT NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'active',
    returned_quantity   INTEGER         NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_order_items PRIMARY KEY (id),
    CONSTRAINT fk_oi_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE RESTRICT,
    CONSTRAINT fk_oi_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL,
    CONSTRAINT fk_oi_variant FOREIGN KEY (variant_id) REFERENCES product_variants (id) ON DELETE SET NULL,
    CONSTRAINT fk_oi_vendor FOREIGN KEY (vendor_id) REFERENCES vendors (id) ON DELETE SET NULL,
    CONSTRAINT chk_oi_quantity CHECK (quantity > 0),
    CONSTRAINT chk_oi_returned CHECK (returned_quantity <= quantity),
    CONSTRAINT chk_oi_status CHECK (status IN ('active', 'cancelled', 'returned'))
);

CREATE TABLE order_status_history (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    order_id        UUID            NOT NULL,
    status          VARCHAR(30)     NOT NULL,
    payment_status  VARCHAR(30)     NULL,
    comment         TEXT            NULL,
    changed_by      UUID            NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_order_status_history PRIMARY KEY (id),
    CONSTRAINT fk_osh_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE RESTRICT,
    CONSTRAINT fk_osh_changed_by FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL
);

-- ============================================================
-- DOMAIN 9: PAYMENTS
-- ============================================================

CREATE TABLE payments (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    order_id            UUID            NOT NULL,
    provider            VARCHAR(30)     NOT NULL,
    provider_order_id   VARCHAR(255)    NULL,
    amount              NUMERIC(12,2)   NOT NULL,
    currency            CHAR(3)         NOT NULL DEFAULT 'INR',
    status              VARCHAR(20)     NOT NULL DEFAULT 'pending',
    method              VARCHAR(30)     NULL,
    idempotency_key     VARCHAR(255)    NOT NULL,
    metadata            TEXT            NULL,
    expires_at          TIMESTAMPTZ     NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_payments PRIMARY KEY (id),
    CONSTRAINT uq_payments_idempotency UNIQUE (idempotency_key),
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE RESTRICT,
    CONSTRAINT chk_payments_provider CHECK (provider IN ('razorpay', 'stripe', 'cod', 'other')),
    CONSTRAINT chk_payments_status CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    CONSTRAINT chk_payments_amount CHECK (amount > 0)
);

CREATE TABLE payment_transactions (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    payment_id              UUID            NOT NULL,
    provider_transaction_id VARCHAR(255)    NULL,
    type                    VARCHAR(20)     NOT NULL,
    amount                  NUMERIC(12,2)   NOT NULL,
    currency                CHAR(3)         NOT NULL DEFAULT 'INR',
    status                  VARCHAR(20)     NOT NULL,
    failure_code            VARCHAR(100)    NULL,
    failure_message         TEXT            NULL,
    metadata                TEXT            NULL,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_payment_transactions PRIMARY KEY (id),
    CONSTRAINT fk_pt_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE RESTRICT,
    CONSTRAINT chk_pt_type CHECK (type IN ('charge', 'refund', 'partial_refund', 'chargeback')),
    CONSTRAINT chk_pt_amount CHECK (amount > 0)
);

CREATE TABLE refunds (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    order_id            UUID            NOT NULL,
    payment_id          UUID            NOT NULL,
    initiated_by        UUID            NOT NULL,
    amount              NUMERIC(12,2)   NOT NULL,
    reason              TEXT            NOT NULL,
    type                VARCHAR(20)     NOT NULL,
    status              VARCHAR(20)     NOT NULL DEFAULT 'pending',
    provider_refund_id  VARCHAR(255)    NULL,
    failure_reason      TEXT            NULL,
    completed_at        TIMESTAMPTZ     NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_refunds PRIMARY KEY (id),
    CONSTRAINT fk_refunds_order FOREIGN KEY (order_id) REFERENCES orders (id),
    CONSTRAINT fk_refunds_payment FOREIGN KEY (payment_id) REFERENCES payments (id),
    CONSTRAINT fk_refunds_initiated_by FOREIGN KEY (initiated_by) REFERENCES users (id),
    CONSTRAINT chk_refunds_type CHECK (type IN ('full', 'partial', 'item')),
    CONSTRAINT chk_refunds_status CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    CONSTRAINT chk_refunds_amount CHECK (amount > 0)
);

-- ============================================================
-- DOMAIN 10: SHIPPING
-- ============================================================

CREATE TABLE shipments (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    order_id            UUID            NOT NULL,
    provider            VARCHAR(100)    NULL,
    tracking_number     VARCHAR(255)    NULL,
    tracking_url        VARCHAR(1000)   NULL,
    status              VARCHAR(30)     NOT NULL DEFAULT 'pending',
    shipping_address    TEXT            NOT NULL,
    weight_grams        INTEGER         NULL,
    package_dimensions  TEXT            NULL,
    estimated_delivery  DATE            NULL,
    shipped_at          TIMESTAMPTZ     NULL,
    delivered_at        TIMESTAMPTZ     NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_shipments PRIMARY KEY (id),
    CONSTRAINT fk_shipments_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE RESTRICT,
    CONSTRAINT chk_shipments_status CHECK (status IN ('pending','ready_to_ship','picked_up','in_transit','out_for_delivery','delivered','delivery_failed','returned'))
);

CREATE TABLE shipment_items (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    shipment_id     UUID            NOT NULL,
    order_item_id   UUID            NOT NULL,
    quantity        INTEGER         NOT NULL,
    CONSTRAINT pk_shipment_items PRIMARY KEY (id),
    CONSTRAINT uq_shipment_items UNIQUE (shipment_id, order_item_id),
    CONSTRAINT fk_si_shipment FOREIGN KEY (shipment_id) REFERENCES shipments (id) ON DELETE CASCADE,
    CONSTRAINT fk_si_order_item FOREIGN KEY (order_item_id) REFERENCES order_items (id),
    CONSTRAINT chk_si_quantity CHECK (quantity > 0)
);

CREATE TABLE shipment_tracking_events (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    shipment_id     UUID            NOT NULL,
    status          VARCHAR(30)     NOT NULL,
    description     TEXT            NULL,
    location        VARCHAR(255)    NULL,
    occurred_at     TIMESTAMPTZ     NOT NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_shipment_tracking_events PRIMARY KEY (id),
    CONSTRAINT fk_ste_shipment FOREIGN KEY (shipment_id) REFERENCES shipments (id) ON DELETE CASCADE
);

-- ============================================================
-- DOMAIN 11: PROMOTIONS (continued — coupon_usages)
-- ============================================================

CREATE TABLE coupon_usages (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    coupon_id       UUID            NOT NULL,
    order_id        UUID            NOT NULL,
    customer_id     UUID            NOT NULL,
    discount_amount NUMERIC(10,2)   NOT NULL,
    used_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_coupon_usages PRIMARY KEY (id),
    CONSTRAINT uq_coupon_usages UNIQUE (coupon_id, order_id),
    CONSTRAINT fk_cu_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (id),
    CONSTRAINT fk_cu_order FOREIGN KEY (order_id) REFERENCES orders (id),
    CONSTRAINT fk_cu_customer FOREIGN KEY (customer_id) REFERENCES customers (id)
);

-- ============================================================
-- DOMAIN 12: REVIEWS
-- ============================================================

CREATE TABLE product_reviews (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    product_id              UUID            NOT NULL,
    customer_id             UUID            NOT NULL,
    order_item_id           UUID            NULL,
    rating                  SMALLINT        NOT NULL,
    title                   VARCHAR(255)    NULL,
    body                    TEXT            NULL,
    is_verified_purchase    BOOLEAN         NOT NULL DEFAULT FALSE,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'pending',
    helpful_count           INTEGER         NOT NULL DEFAULT 0,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at              TIMESTAMPTZ     NULL,
    CONSTRAINT pk_product_reviews PRIMARY KEY (id),
    CONSTRAINT uq_product_reviews UNIQUE (product_id, customer_id),
    CONSTRAINT fk_pr_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
    CONSTRAINT fk_pr_customer FOREIGN KEY (customer_id) REFERENCES customers (id),
    CONSTRAINT fk_pr_order_item FOREIGN KEY (order_item_id) REFERENCES order_items (id) ON DELETE SET NULL,
    CONSTRAINT chk_pr_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_pr_status CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE TABLE review_images (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    review_id       UUID            NOT NULL,
    url             VARCHAR(1000)   NOT NULL,
    sort_order      INTEGER         NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_review_images PRIMARY KEY (id),
    CONSTRAINT fk_ri_review FOREIGN KEY (review_id) REFERENCES product_reviews (id) ON DELETE CASCADE
);

-- ============================================================
-- DOMAIN 13: NOTIFICATIONS
-- ============================================================

CREATE TABLE device_tokens (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    token           VARCHAR(500)    NOT NULL,
    platform        VARCHAR(10)     NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    last_used_at    TIMESTAMPTZ     NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_device_tokens PRIMARY KEY (id),
    CONSTRAINT uq_device_tokens_token UNIQUE (token),
    CONSTRAINT fk_dt_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_dt_platform CHECK (platform IN ('android', 'ios'))
);

CREATE TABLE notifications (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    type            VARCHAR(50)     NOT NULL,
    channel         VARCHAR(20)     NOT NULL,
    title           VARCHAR(255)    NOT NULL,
    body            TEXT            NOT NULL,
    data            TEXT            NULL,
    is_read         BOOLEAN         NOT NULL DEFAULT FALSE,
    read_at         TIMESTAMPTZ     NULL,
    sent_at         TIMESTAMPTZ     NULL,
    failed_at       TIMESTAMPTZ     NULL,
    failure_reason  TEXT            NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_notifications PRIMARY KEY (id),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_notifications_channel CHECK (channel IN ('push', 'email', 'sms', 'in_app'))
);

CREATE TABLE notification_preferences (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL,
    notification_type   VARCHAR(50)     NOT NULL,
    push_enabled        BOOLEAN         NOT NULL DEFAULT TRUE,
    email_enabled       BOOLEAN         NOT NULL DEFAULT TRUE,
    sms_enabled         BOOLEAN         NOT NULL DEFAULT FALSE,
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_notification_preferences PRIMARY KEY (id),
    CONSTRAINT uq_np UNIQUE (user_id, notification_type),
    CONSTRAINT fk_np_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- ============================================================
-- DOMAIN 14: AUDIT
-- ============================================================

CREATE TABLE audit_logs (
    id              BIGSERIAL       NOT NULL,
    user_id         UUID            NULL,
    action          VARCHAR(30)     NOT NULL,
    resource_type   VARCHAR(100)    NOT NULL,
    resource_id     UUID            NOT NULL,
    old_values      TEXT            NULL,
    new_values      TEXT            NULL,
    ip_address      VARCHAR(45)     NULL,
    user_agent      VARCHAR(500)    NULL,
    request_id      VARCHAR(100)    NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_audit_logs PRIMARY KEY (id),
    CONSTRAINT fk_al_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT chk_al_action CHECK (action IN ('create','update','delete','login','logout','permission_change'))
);

-- ============================================================
-- INDEXES
-- ============================================================

-- users
CREATE UNIQUE INDEX idx_users_email ON users (email);
CREATE UNIQUE INDEX idx_users_phone ON users (phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_users_active ON users (is_active) WHERE deleted_at IS NULL;

-- refresh_tokens
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens (expires_at);

-- otp_verifications
CREATE INDEX idx_otp_identifier_purpose ON otp_verifications (identifier, purpose) WHERE verified_at IS NULL;

-- categories
CREATE INDEX idx_categories_parent_id ON categories (parent_id);
CREATE INDEX idx_categories_path ON categories (path);

-- products
CREATE INDEX idx_products_category_id ON products (category_id);
CREATE INDEX idx_products_brand_id ON products (brand_id);
CREATE INDEX idx_products_vendor_id ON products (vendor_id);
CREATE INDEX idx_products_status ON products (status) WHERE deleted_at IS NULL;

-- product_variants
CREATE INDEX idx_product_variants_product_id ON product_variants (product_id);

-- inventory
CREATE INDEX idx_inventory_low_stock ON inventory (quantity_on_hand) WHERE quantity_on_hand <= reorder_point;

-- inventory_transactions
CREATE INDEX idx_inv_tx_variant_id ON inventory_transactions (variant_id);
CREATE INDEX idx_inv_tx_reference ON inventory_transactions (reference_type, reference_id);
CREATE INDEX idx_inv_tx_created_at ON inventory_transactions (created_at);

-- carts
CREATE INDEX idx_carts_customer_active ON carts (customer_id) WHERE status = 'active';
CREATE INDEX idx_carts_session_id ON carts (session_id) WHERE session_id IS NOT NULL;

-- orders
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
CREATE INDEX idx_orders_status ON orders (status);
CREATE INDEX idx_orders_payment_status ON orders (payment_status);
CREATE INDEX idx_orders_created_at ON orders (created_at);
CREATE INDEX idx_orders_customer_status ON orders (customer_id, status, created_at DESC);

-- order_items
CREATE INDEX idx_order_items_order_id ON order_items (order_id);
CREATE INDEX idx_order_items_product_id ON order_items (product_id);

-- order_status_history
CREATE INDEX idx_osh_order_id ON order_status_history (order_id);

-- payments
CREATE INDEX idx_payments_order_id ON payments (order_id);
CREATE INDEX idx_payments_provider_order_id ON payments (provider_order_id) WHERE provider_order_id IS NOT NULL;

-- payment_transactions
CREATE INDEX idx_pt_payment_id ON payment_transactions (payment_id);

-- refunds
CREATE INDEX idx_refunds_order_id ON refunds (order_id);

-- shipments
CREATE INDEX idx_shipments_order_id ON shipments (order_id);
CREATE INDEX idx_shipments_tracking ON shipments (tracking_number) WHERE tracking_number IS NOT NULL;

-- shipment_tracking_events
CREATE INDEX idx_ste_shipment_id ON shipment_tracking_events (shipment_id, occurred_at DESC);

-- coupons
CREATE INDEX idx_coupons_active ON coupons (is_active, starts_at, expires_at);

-- coupon_usages
CREATE INDEX idx_cu_coupon_customer ON coupon_usages (coupon_id, customer_id);

-- product_reviews
CREATE INDEX idx_reviews_product_status ON product_reviews (product_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_reviews_customer_id ON product_reviews (customer_id);

-- recently_viewed_products
CREATE INDEX idx_rv_customer_time ON recently_viewed_products (customer_id, viewed_at DESC);

-- notifications
CREATE INDEX idx_notifications_user_time ON notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_unread ON notifications (user_id) WHERE is_read = FALSE;

-- audit_logs
CREATE INDEX idx_al_user_id ON audit_logs (user_id);
CREATE INDEX idx_al_resource ON audit_logs (resource_type, resource_id);
CREATE INDEX idx_al_created_at ON audit_logs (created_at);
