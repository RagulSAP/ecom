# ADR-003: Order Data Snapshots

**Date**: 2026-09-27
**Status**: Accepted

## Decision

Orders and order_items store snapshots of customer, address, product, price, and tax data at the time of order creation. These are stored as denormalized columns (VARCHAR, NUMERIC) and JSONB fields, not as live FKs.

## Context

E-commerce regulations and auditing require that an order record reflects what was agreed at purchase time. If a customer changes their address, or a product is deleted, or a price is updated — the order must still reflect the original state.

## Consequences

- FK columns (product_id, variant_id, customer_id) remain on order_items for reporting joins, but are SET NULL on deletion rather than CASCADE or RESTRICT
- Snapshot columns (product_name, sku, unit_price, tax_rate, shipping_address JSONB) are written at order creation and never updated
- Storage overhead: small — the duplicated data per order is minimal
- Historical reporting on orders does not require joining to the live catalog tables
