-- =============================================================================
-- E-COMMERCE 360° BUSINESS INTELLIGENCE PLATFORM
-- Script 03: Data Quality Validation & Sanity Audits
-- DBMS: MySQL 8.0+
-- =============================================================================

USE ecommerce_analytics;

-- =============================================================================
-- 1. STAGING TABLE ROW COUNT AUDIT
-- Expected counts based on official Olist dataset release
-- =============================================================================
SELECT 'raw_customers' AS table_name, COUNT(*) AS total_rows FROM raw_customers
UNION ALL
SELECT 'raw_orders', COUNT(*) FROM raw_orders
UNION ALL
SELECT 'raw_order_items', COUNT(*) FROM raw_order_items
UNION ALL
SELECT 'raw_order_payments', COUNT(*) FROM raw_order_payments
UNION ALL
SELECT 'raw_order_reviews', COUNT(*) FROM raw_order_reviews
UNION ALL
SELECT 'raw_products', COUNT(*) FROM raw_products
UNION ALL
SELECT 'raw_sellers', COUNT(*) FROM raw_sellers
UNION ALL
SELECT 'raw_geolocation', COUNT(*) FROM raw_geolocation
UNION ALL
SELECT 'raw_category_translation', COUNT(*) FROM raw_category_translation;

-- =============================================================================
-- 2. PRIMARY KEY UNIQUENESS & DUPLICATE IDENTIFICATION
-- =============================================================================

-- Customer ID uniqueness
SELECT customer_id, COUNT(*) AS duplicate_count
FROM raw_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Order ID uniqueness
SELECT order_id, COUNT(*) AS duplicate_count
FROM raw_orders
GROUP BY order_id
HAVING COUNT(*) > 1;

-- Order Items composite key uniqueness
SELECT order_id, order_item_id, COUNT(*) AS duplicate_count
FROM raw_order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- Product ID uniqueness
SELECT product_id, COUNT(*) AS duplicate_count
FROM raw_products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- =============================================================================
-- 3. REFERENTIAL INTEGRITY (ORPHAN RECORD CHECKS)
-- =============================================================================

-- Orders referencing non-existent customers
SELECT COUNT(*) AS orphaned_orders_count
FROM raw_orders o
LEFT JOIN raw_customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Order items referencing non-existent orders
SELECT COUNT(*) AS orphaned_order_items_order_fk
FROM raw_order_items oi
LEFT JOIN raw_orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Order items referencing non-existent products
SELECT COUNT(*) AS orphaned_order_items_product_fk
FROM raw_order_items oi
LEFT JOIN raw_products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Order items referencing non-existent sellers
SELECT COUNT(*) AS orphaned_order_items_seller_fk
FROM raw_order_items oi
LEFT JOIN raw_sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Payments referencing non-existent orders
SELECT COUNT(*) AS orphaned_payments_count
FROM raw_order_payments p
LEFT JOIN raw_orders o ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Reviews referencing non-existent orders
SELECT COUNT(*) AS orphaned_reviews_count
FROM raw_order_reviews r
LEFT JOIN raw_orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL;

-- =============================================================================
-- 4. MISSING VALUES & NULLABILITY AUDIT
-- =============================================================================
SELECT 
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_status,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_purchase_time,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_delivered_date,
    SUM(CASE WHEN order_status = 'delivered' AND order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS delivered_missing_timestamp
FROM raw_orders;

-- Missing product categories
SELECT 
    COUNT(*) AS total_products,
    SUM(CASE WHEN product_category_name IS NULL OR TRIM(product_category_name) = '' THEN 1 ELSE 0 END) AS null_or_empty_category,
    ROUND(100.0 * SUM(CASE WHEN product_category_name IS NULL OR TRIM(product_category_name) = '' THEN 1 ELSE 0 END) / COUNT(*), 2) AS missing_category_pct
FROM raw_products;

-- =============================================================================
-- 5. NUMERICAL & DOMAIN SANITY CHECKS
-- =============================================================================

-- Non-positive item prices or freight
SELECT 
    COUNT(*) AS invalid_items_count,
    SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END) AS non_positive_price,
    SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END) AS negative_freight
FROM raw_order_items;

-- Review scores out of bounds [1, 5]
SELECT 
    COUNT(*) AS out_of_bounds_reviews
FROM raw_order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;

-- Payment values non-positive
SELECT 
    COUNT(*) AS zero_or_negative_payments
FROM raw_order_payments
WHERE payment_value <= 0;

-- =============================================================================
-- 6. TEMPORAL ANOMALIES & LOGISTICAL LOGIC CHECKS
-- =============================================================================

-- Delivery occurred before purchase
SELECT 
    order_id,
    order_purchase_timestamp,
    order_delivered_customer_date
FROM raw_orders
WHERE order_delivered_customer_date < order_purchase_timestamp;

-- Carrier delivery to customer occurred before carrier received package
SELECT 
    order_id,
    order_delivered_carrier_date,
    order_delivered_customer_date
FROM raw_orders
WHERE order_delivered_customer_date < order_delivered_carrier_date;
