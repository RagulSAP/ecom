# Business Rules — Enterprise E-Commerce Platform

## 1. Authentication & Identity

- BR-AUTH-01: A user account requires a unique email address.
- BR-AUTH-02: Phone number is optional but must be unique if provided.
- BR-AUTH-03: Passwords must be hashed with bcrypt (min cost factor 12). Plain-text passwords must never be stored or logged.
- BR-AUTH-04: Access tokens expire in 15 minutes. Refresh tokens expire in 30 days.
- BR-AUTH-05: A refresh token is single-use; it is invalidated on each use and a new one is issued (token rotation).
- BR-AUTH-06: After 5 consecutive failed login attempts, the account is rate-limited for 15 minutes.
- BR-AUTH-07: OTP codes expire in 10 minutes. Maximum 3 attempts per OTP.
- BR-AUTH-08: Email verification is required before a customer can place orders.
- BR-AUTH-09: Password reset invalidates all existing refresh tokens for that user.
- BR-AUTH-10: Admin users must have MFA (future phase); architecture must not prevent adding MFA later.

## 2. Product Catalog

- BR-CAT-01: Every product must belong to exactly one leaf-level category.
- BR-CAT-02: A product must have at least one active variant.
- BR-CAT-03: Each variant must have a globally unique SKU.
- BR-CAT-04: Exactly one variant per product must be marked as the default variant (is_default = true).
- BR-CAT-05: Product prices are stored as NUMERIC(12,2) in the base currency. No floating-point arithmetic.
- BR-CAT-06: compare_at_price (original price) must be greater than price (sale price) if set.
- BR-CAT-07: A product in "draft" status is not visible to customers.
- BR-CAT-08: Deleting a category does not delete its products; products must be re-categorized first (or category soft-deleted and products marked inactive).
- BR-CAT-09: Category hierarchy supports unlimited depth; circular references must be prevented at the application layer.
- BR-CAT-10: Slugs for products and categories must be unique and URL-safe.

## 3. Inventory

- BR-INV-01: quantity_on_hand must never go below 0.
- BR-INV-02: quantity_reserved must never exceed quantity_on_hand.
- BR-INV-03: quantity_available = quantity_on_hand - quantity_reserved (computed or enforced by application).
- BR-INV-04: When a cart item is added during checkout, inventory is reserved atomically. If reservation fails (insufficient stock), the cart item cannot proceed to order.
- BR-INV-05: Reserved inventory is released if: (a) checkout is abandoned (cart expires), (b) payment fails, (c) order is cancelled.
- BR-INV-06: All inventory changes must create an inventory_transaction record (audit trail).
- BR-INV-07: Products with allow_backorder = true may proceed to order even with quantity_available = 0.
- BR-INV-08: Inventory adjustments by admin must include a reason note.

## 4. Cart

- BR-CART-01: A logged-in customer has at most one active cart.
- BR-CART-02: Guest carts are identified by session_id and expire after 30 days of inactivity.
- BR-CART-03: On login, a guest cart is merged with the customer's existing cart (quantity addition, with variant-level deduplication).
- BR-CART-04: Cart item quantity must be ≥ 1.
- BR-CART-05: At checkout initiation, prices must be re-validated against current product prices. If prices changed, the customer must be informed.
- BR-CART-06: At checkout, inventory availability must be re-validated with locking.
- BR-CART-07: A coupon can be applied to at most one cart at a time. Removing the cart removes the coupon reservation.
- BR-CART-08: Cart totals (subtotal, discount, tax, shipping, total) are computed server-side, never trusted from client.
- BR-CART-09: Cart converts to status "converted" when an order is created from it.

## 5. Orders

- BR-ORD-01: An order is immutable once created. Status transitions occur through the order_status_history mechanism.
- BR-ORD-02: Order records must snapshot: customer name/email/phone, shipping address, billing address, product name, variant name, SKU, unit price, tax rate, and coupon code. These snapshots must not be updated if the underlying data changes later.
- BR-ORD-03: Order numbers are sequential, human-readable (e.g., ORD-2024-000001), and unique.
- BR-ORD-04: Order totals: total_amount = subtotal - discount_amount + shipping_amount + tax_amount.
- BR-ORD-05: An order can be cancelled only if it is in status: pending, confirmed, or processing (before shipment).
- BR-ORD-06: Partial cancellation cancels individual order_items; the order status reflects the remaining items.
- BR-ORD-07: An order cannot be cancelled after shipment without initiating a return.
- BR-ORD-08: All order status transitions must be recorded in order_status_history with timestamp and actor.
- BR-ORD-09: Cancellation releases reserved inventory back to available stock.
- BR-ORD-10: An order can have multiple shipments (split shipment) in future phases; schema must support this.

## 6. Payments

- BR-PAY-01: Payment status is determined exclusively by server-side verification and webhook events. Client-reported payment status must never be trusted.
- BR-PAY-02: An order moves to payment_status = "paid" only after server-side webhook confirmation or server-side verification API call.
- BR-PAY-03: Payment provider credentials are stored in environment variables / Secrets Manager only. Never in database or code.
- BR-PAY-04: Raw card numbers must never pass through the application server.
- BR-PAY-05: Webhook events must be deduplicated. The same webhook event_id must be idempotent.
- BR-PAY-06: Every payment interaction (initiation, success, failure, refund) creates a payment_transaction record.
- BR-PAY-07: Refund amount must not exceed the total paid amount minus any already-refunded amounts.
- BR-PAY-08: Partial refunds are supported at the item level.
- BR-PAY-09: Payment retry is allowed only while order payment_status = "failed"; a new payment record is created per attempt.
- BR-PAY-10: COD (Cash on Delivery) orders are created with payment_status = "pending"; marked paid on delivery confirmation.

## 7. Shipping

- BR-SHIP-01: A shipment can only be created for an order with payment_status = "paid" (except COD).
- BR-SHIP-02: Shipping address on a shipment is a snapshot from the order's shipping_address; not a live FK to customer_addresses.
- BR-SHIP-03: Delivery status transitions must be logged in shipment_tracking_events.
- BR-SHIP-04: The shipping provider integration is abstracted; the core system must not contain provider-specific logic in business services.
- BR-SHIP-05: Estimated delivery date is advisory; not contractual.

## 8. Promotions & Coupons

- BR-PROMO-01: A coupon code is case-insensitive and stored uppercase.
- BR-PROMO-02: A coupon cannot be applied if: (a) expired, (b) inactive, (c) usage_limit reached, (d) customer has exceeded usage_per_customer limit, (e) order total is below min_order_amount.
- BR-PROMO-03: For percentage discounts, the actual discount is capped at max_discount_amount.
- BR-PROMO-04: Discount is applied to eligible items only (when applicable_to ≠ "all").
- BR-PROMO-05: Coupon usage is recorded in coupon_usages when an order is successfully placed. Usage count is not incremented on cart application — only on order creation.
- BR-PROMO-06: If an order using a coupon is cancelled, the coupon usage is reversed (current_usage_count decremented).
- BR-PROMO-07: A customer can apply at most one coupon per order.

## 9. Reviews

- BR-REV-01: A customer can submit at most one review per product.
- BR-REV-02: Reviews are flagged is_verified_purchase = true only when the customer has a completed order containing that product.
- BR-REV-03: Reviews require moderation (status = "pending") before public display unless auto-approval is configured.
- BR-REV-04: Rating must be an integer between 1 and 5.
- BR-REV-05: Review images are optional; maximum 5 images per review.

## 10. Multi-Vendor

- BR-VEND-01: In single-vendor mode, vendor_id on products can be null (or a default platform vendor).
- BR-VEND-02: A vendor user must be associated with exactly one vendor.
- BR-VEND-03: Vendors can only manage their own products, inventory, and orders.
- BR-VEND-04: Platform commission is calculated per order_item based on vendor commission rate.
- BR-VEND-05: Vendor payout records are calculated after order delivery and return window expiry.

## 11. Financial Rules

- BR-FIN-01: All monetary values use NUMERIC(12,2) in PostgreSQL.
- BR-FIN-02: Rounding follows ROUND_HALF_UP at the application layer.
- BR-FIN-03: Tax is calculated per order_item, not on the order total (to support mixed-rate products).
- BR-FIN-04: All financial operations (inventory reservation + order creation + payment) happen within a database transaction.
- BR-FIN-05: Historical financial data (order totals, payment amounts) must not be mutated after the fact.

## 12. Data Retention & Soft Deletes

- BR-DATA-01: Users are soft-deleted (deleted_at timestamp); hard delete only by explicit GDPR request.
- BR-DATA-02: Products and categories are soft-deleted; existing order references remain valid.
- BR-DATA-03: Orders, order_items, payment_transactions, and audit_logs are never deleted.
- BR-DATA-04: Customer address soft-delete preserves existing order shipping snapshots (snapshots are JSONB on orders).
- BR-DATA-05: Audit logs are append-only with no update or delete capability.
