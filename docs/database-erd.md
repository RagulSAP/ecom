# Database ERD — Enterprise E-Commerce Platform

> Diagrams use [Mermaid](https://mermaid.js.org/) syntax. Render in GitHub, GitLab, or any Mermaid-compatible viewer.

---

## ERD 1: Identity & Access Management

```mermaid
erDiagram
    users {
        uuid id PK
        varchar email UK
        varchar phone UK
        varchar password_hash
        varchar first_name
        varchar last_name
        boolean is_active
        boolean is_verified
        boolean is_staff
        timestamptz last_login_at
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }

    roles {
        uuid id PK
        varchar name UK
        text description
        boolean is_system
        timestamptz created_at
        timestamptz updated_at
    }

    permissions {
        uuid id PK
        varchar code UK
        varchar module
        text description
        timestamptz created_at
    }

    role_permissions {
        uuid role_id FK
        uuid permission_id FK
    }

    user_roles {
        uuid user_id FK
        uuid role_id FK
        uuid granted_by FK
        timestamptz granted_at
    }

    refresh_tokens {
        uuid id PK
        uuid user_id FK
        varchar token_hash UK
        timestamptz expires_at
        timestamptz revoked_at
        inet ip_address
        varchar user_agent
        timestamptz created_at
    }

    otp_verifications {
        uuid id PK
        uuid user_id FK
        varchar identifier
        varchar purpose
        varchar otp_hash
        timestamptz expires_at
        timestamptz verified_at
        smallint attempts
        timestamptz created_at
    }

    users ||--o{ user_roles : "has"
    roles ||--o{ user_roles : "assigned via"
    roles ||--o{ role_permissions : "grants"
    permissions ||--o{ role_permissions : "belongs to"
    users ||--o{ refresh_tokens : "owns"
    users ||--o{ otp_verifications : "has"
    users ||--o{ user_roles : "granted_by"
```

---

## ERD 2: Customer & Vendor

```mermaid
erDiagram
    users {
        uuid id PK
    }

    customers {
        uuid id PK
        uuid user_id FK
        varchar display_name
        varchar avatar_url
        date date_of_birth
        varchar gender
        timestamptz created_at
        timestamptz updated_at
    }

    customer_addresses {
        uuid id PK
        uuid customer_id FK
        varchar label
        varchar first_name
        varchar last_name
        varchar phone
        varchar address_line1
        varchar address_line2
        varchar city
        varchar state
        varchar postal_code
        char country
        boolean is_default
        boolean is_active
        timestamptz created_at
        timestamptz updated_at
    }

    vendors {
        uuid id PK
        varchar name
        varchar slug UK
        varchar email UK
        varchar phone
        varchar logo_url
        varchar status
        numeric commission_rate
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }

    vendor_users {
        uuid id PK
        uuid vendor_id FK
        uuid user_id FK
        varchar vendor_role
        boolean is_active
        timestamptz created_at
        timestamptz updated_at
    }

    users ||--|| customers : "profile"
    customers ||--o{ customer_addresses : "has many"
    vendors ||--o{ vendor_users : "has staff"
    users ||--o{ vendor_users : "works for"
```

---

## ERD 3: Product Catalog

```mermaid
erDiagram
    categories {
        uuid id PK
        uuid parent_id FK
        varchar name
        varchar slug UK
        text description
        varchar image_url
        integer display_order
        smallint level
        varchar path
        boolean is_active
        timestamptz deleted_at
    }

    brands {
        uuid id PK
        varchar name
        varchar slug UK
        varchar logo_url
        boolean is_active
        timestamptz deleted_at
    }

    attribute_groups {
        uuid id PK
        varchar name UK
        integer display_order
    }

    attribute_definitions {
        uuid id PK
        uuid group_id FK
        varchar name
        varchar code UK
        varchar input_type
        varchar unit
        boolean is_filterable
        boolean is_variant_attribute
    }

    products {
        uuid id PK
        uuid vendor_id FK
        uuid category_id FK
        uuid brand_id FK
        varchar name
        varchar slug UK
        text short_description
        text description
        varchar status
        boolean is_featured
        text[] tags
        tsvector search_vector
        timestamptz deleted_at
    }

    product_variants {
        uuid id PK
        uuid product_id FK
        varchar sku UK
        varchar name
        numeric price
        numeric compare_at_price
        numeric cost_price
        integer weight_grams
        boolean is_default
        boolean is_active
        integer sort_order
    }

    variant_attribute_values {
        uuid id PK
        uuid variant_id FK
        uuid attribute_id FK
        varchar value
    }

    product_images {
        uuid id PK
        uuid product_id FK
        uuid variant_id FK
        varchar url
        varchar alt_text
        integer sort_order
        boolean is_primary
    }

    product_specifications {
        uuid id PK
        uuid product_id FK
        varchar label
        varchar value
        integer sort_order
    }

    categories ||--o{ categories : "parent of"
    categories ||--o{ products : "classifies"
    brands ||--o{ products : "brands"
    products ||--o{ product_variants : "has"
    products ||--o{ product_images : "has"
    products ||--o{ product_specifications : "has"
    product_variants ||--o{ variant_attribute_values : "defined by"
    product_variants ||--o{ product_images : "has variant images"
    attribute_definitions ||--o{ variant_attribute_values : "defines"
    attribute_groups ||--o{ attribute_definitions : "groups"
```

---

## ERD 4: Inventory

```mermaid
erDiagram
    product_variants {
        uuid id PK
        varchar sku
    }

    inventory {
        uuid id PK
        uuid variant_id FK
        integer quantity_on_hand
        integer quantity_reserved
        integer reorder_point
        integer reorder_quantity
        boolean allow_backorder
        timestamptz updated_at
    }

    inventory_transactions {
        uuid id PK
        uuid variant_id FK
        varchar transaction_type
        integer quantity_change
        integer quantity_before
        integer quantity_after
        varchar reference_type
        uuid reference_id
        text notes
        uuid created_by FK
        timestamptz created_at
    }

    product_variants ||--|| inventory : "has stock"
    product_variants ||--o{ inventory_transactions : "tracks"
```

---

## ERD 5: Cart & Engagement

```mermaid
erDiagram
    customers {
        uuid id PK
    }

    products {
        uuid id PK
    }

    product_variants {
        uuid id PK
    }

    wishlists {
        uuid id PK
        uuid customer_id FK
        varchar name
        boolean is_public
        timestamptz created_at
        timestamptz updated_at
    }

    wishlist_items {
        uuid id PK
        uuid wishlist_id FK
        uuid product_id FK
        uuid variant_id FK
        timestamptz added_at
    }

    recently_viewed_products {
        uuid id PK
        uuid customer_id FK
        uuid product_id FK
        uuid variant_id FK
        timestamptz viewed_at
    }

    carts {
        uuid id PK
        uuid customer_id FK
        varchar session_id
        varchar status
        uuid coupon_id FK
        char currency
        timestamptz expires_at
        timestamptz created_at
        timestamptz updated_at
    }

    cart_items {
        uuid id PK
        uuid cart_id FK
        uuid product_id FK
        uuid variant_id FK
        integer quantity
        numeric unit_price
        timestamptz created_at
        timestamptz updated_at
    }

    customers ||--o{ wishlists : "owns"
    wishlists ||--o{ wishlist_items : "contains"
    products ||--o{ wishlist_items : "in"
    product_variants ||--o{ wishlist_items : "variant in"
    customers ||--o{ recently_viewed_products : "viewed"
    customers ||--o{ carts : "has"
    carts ||--o{ cart_items : "contains"
    products ||--o{ cart_items : "in cart"
    product_variants ||--o{ cart_items : "variant in cart"
```

---

## ERD 6: Orders

```mermaid
erDiagram
    customers {
        uuid id PK
    }

    orders {
        uuid id PK
        uuid customer_id FK
        varchar order_number UK
        varchar status
        varchar payment_status
        varchar fulfillment_status
        char currency
        varchar customer_email
        varchar customer_name
        jsonb shipping_address
        jsonb billing_address
        numeric subtotal
        numeric discount_amount
        numeric shipping_amount
        numeric tax_amount
        numeric total_amount
        uuid coupon_id FK
        varchar coupon_code
        varchar idempotency_key UK
        timestamptz cancelled_at
        text cancellation_reason
        timestamptz created_at
        timestamptz updated_at
    }

    order_items {
        uuid id PK
        uuid order_id FK
        uuid product_id FK
        uuid variant_id FK
        uuid vendor_id FK
        varchar product_name
        varchar variant_name
        varchar sku
        varchar product_image_url
        integer quantity
        numeric unit_price
        numeric discount_amount
        numeric tax_rate
        numeric tax_amount
        numeric total_amount
        varchar status
        integer returned_quantity
        timestamptz created_at
        timestamptz updated_at
    }

    order_status_history {
        uuid id PK
        uuid order_id FK
        varchar status
        varchar payment_status
        text comment
        uuid changed_by FK
        timestamptz created_at
    }

    customers ||--o{ orders : "places"
    orders ||--o{ order_items : "contains"
    orders ||--o{ order_status_history : "tracks"
```

---

## ERD 7: Payments

```mermaid
erDiagram
    orders {
        uuid id PK
    }

    payments {
        uuid id PK
        uuid order_id FK
        varchar provider
        varchar provider_order_id
        numeric amount
        char currency
        varchar status
        varchar method
        varchar idempotency_key UK
        jsonb metadata
        timestamptz expires_at
        timestamptz created_at
        timestamptz updated_at
    }

    payment_transactions {
        uuid id PK
        uuid payment_id FK
        varchar provider_transaction_id UK
        varchar type
        numeric amount
        char currency
        varchar status
        varchar failure_code
        text failure_message
        jsonb metadata
        timestamptz created_at
    }

    refunds {
        uuid id PK
        uuid order_id FK
        uuid payment_id FK
        uuid initiated_by FK
        numeric amount
        text reason
        varchar type
        varchar status
        varchar provider_refund_id
        text failure_reason
        timestamptz completed_at
        timestamptz created_at
        timestamptz updated_at
    }

    orders ||--o{ payments : "paid via"
    payments ||--o{ payment_transactions : "generates"
    orders ||--o{ refunds : "refunded via"
    payments ||--o{ refunds : "refunded from"
```

---

## ERD 8: Shipping

```mermaid
erDiagram
    orders {
        uuid id PK
    }

    order_items {
        uuid id PK
    }

    shipments {
        uuid id PK
        uuid order_id FK
        varchar provider
        varchar tracking_number
        varchar tracking_url
        varchar status
        jsonb shipping_address
        integer weight_grams
        jsonb package_dimensions
        date estimated_delivery
        timestamptz shipped_at
        timestamptz delivered_at
        timestamptz created_at
        timestamptz updated_at
    }

    shipment_items {
        uuid id PK
        uuid shipment_id FK
        uuid order_item_id FK
        integer quantity
    }

    shipment_tracking_events {
        uuid id PK
        uuid shipment_id FK
        varchar status
        text description
        varchar location
        timestamptz occurred_at
        timestamptz created_at
    }

    orders ||--o{ shipments : "shipped via"
    shipments ||--o{ shipment_items : "contains"
    order_items ||--o{ shipment_items : "shipped in"
    shipments ||--o{ shipment_tracking_events : "tracked by"
```

---

## ERD 9: Promotions

```mermaid
erDiagram
    coupons {
        uuid id PK
        varchar code UK
        text description
        varchar discount_type
        numeric discount_value
        numeric max_discount_amount
        numeric min_order_amount
        varchar applicable_to
        integer usage_limit
        integer usage_per_customer
        integer current_usage_count
        timestamptz starts_at
        timestamptz expires_at
        boolean is_active
        uuid created_by FK
        timestamptz created_at
        timestamptz updated_at
    }

    coupon_applicable_items {
        uuid id PK
        uuid coupon_id FK
        varchar item_type
        uuid item_id
    }

    coupon_usages {
        uuid id PK
        uuid coupon_id FK
        uuid order_id FK
        uuid customer_id FK
        numeric discount_amount
        timestamptz used_at
    }

    customers {
        uuid id PK
    }

    orders {
        uuid id PK
    }

    coupons ||--o{ coupon_applicable_items : "applies to"
    coupons ||--o{ coupon_usages : "used in"
    orders ||--o{ coupon_usages : "uses"
    customers ||--o{ coupon_usages : "redeems"
```

---

## ERD 10: Reviews & Notifications

```mermaid
erDiagram
    products {
        uuid id PK
    }

    customers {
        uuid id PK
    }

    users {
        uuid id PK
    }

    product_reviews {
        uuid id PK
        uuid product_id FK
        uuid customer_id FK
        uuid order_item_id FK
        smallint rating
        varchar title
        text body
        boolean is_verified_purchase
        varchar status
        integer helpful_count
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at
    }

    review_images {
        uuid id PK
        uuid review_id FK
        varchar url
        integer sort_order
        timestamptz created_at
    }

    device_tokens {
        uuid id PK
        uuid user_id FK
        varchar token UK
        varchar platform
        boolean is_active
        timestamptz last_used_at
        timestamptz created_at
        timestamptz updated_at
    }

    notifications {
        uuid id PK
        uuid user_id FK
        varchar type
        varchar channel
        varchar title
        text body
        jsonb data
        boolean is_read
        timestamptz read_at
        timestamptz sent_at
        timestamptz failed_at
        text failure_reason
        timestamptz created_at
    }

    notification_preferences {
        uuid id PK
        uuid user_id FK
        varchar notification_type
        boolean push_enabled
        boolean email_enabled
        boolean sms_enabled
        timestamptz updated_at
    }

    products ||--o{ product_reviews : "reviewed in"
    customers ||--o{ product_reviews : "writes"
    product_reviews ||--o{ review_images : "has images"
    users ||--o{ device_tokens : "registers"
    users ||--o{ notifications : "receives"
    users ||--o{ notification_preferences : "configures"
```

---

## High-Level Domain Relationship Map

```mermaid
graph TD
    IAM["Identity & Access<br/>(users, roles, permissions)"]
    CUST["Customer<br/>(customers, addresses)"]
    VEND["Vendor<br/>(vendors, vendor_users)"]
    CAT["Product Catalog<br/>(categories, brands, products, variants)"]
    INV["Inventory<br/>(inventory, transactions)"]
    ENG["Engagement<br/>(wishlist, recently_viewed)"]
    CART["Cart<br/>(carts, cart_items)"]
    ORD["Orders<br/>(orders, order_items, history)"]
    PAY["Payments<br/>(payments, transactions, refunds)"]
    SHIP["Shipping<br/>(shipments, tracking)"]
    PROMO["Promotions<br/>(coupons, usages)"]
    REV["Reviews<br/>(reviews, images)"]
    NOTIF["Notifications<br/>(device_tokens, notifications)"]
    AUDIT["Audit<br/>(audit_logs)"]

    IAM --> CUST
    IAM --> VEND
    CUST --> ENG
    CUST --> CART
    CUST --> ORD
    VEND --> CAT
    CAT --> INV
    CAT --> ENG
    CAT --> CART
    CAT --> ORD
    CAT --> REV
    CART --> ORD
    PROMO --> CART
    PROMO --> ORD
    ORD --> PAY
    ORD --> SHIP
    ORD --> REV
    IAM --> AUDIT
    ORD --> AUDIT
    PAY --> AUDIT
```
