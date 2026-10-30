-- =============================================================================
-- E-COMMERCE 360° BUSINESS INTELLIGENCE PLATFORM
-- Script 04: Data Cleaning & Star Schema ETL Pipeline
-- DBMS: MySQL 8.0+
-- =============================================================================

USE ecommerce_analytics;

-- =============================================================================
-- STEP 1: POPULATE DATE DIMENSION (dim_date)
-- Covers calendar dates from 2016-01-01 to 2018-12-31
-- =============================================================================
TRUNCATE TABLE dim_date;

INSERT INTO dim_date (
    date_key,
    full_date_description,
    day_of_month,
    day_name,
    day_of_week,
    is_weekend,
    month_number,
    month_name,
    year_month,
    quarter_number,
    year_quarter,
    year_number
)
WITH RECURSIVE date_seq AS (
    SELECT CAST('2016-01-01' AS DATE) AS d_date
    UNION ALL
    SELECT DATE_ADD(d_date, INTERVAL 1 DAY)
    FROM date_seq
    WHERE d_date < '2018-12-31'
)
SELECT 
    d_date AS date_key,
    DATE_FORMAT(d_date, '%W, %M %e, %Y') AS full_date_description,
    DAY(d_date) AS day_of_month,
    DATE_FORMAT(d_date, '%W') AS day_name,
    DAYOFWEEK(d_date) AS day_of_week,
    CASE WHEN DAYOFWEEK(d_date) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend,
    MONTH(d_date) AS month_number,
    DATE_FORMAT(d_date, '%M') AS month_name,
    DATE_FORMAT(d_date, '%Y-%m') AS year_month,
    QUARTER(d_date) AS quarter_number,
    CONCAT(YEAR(d_date), '-Q', QUARTER(d_date)) AS year_quarter,
    YEAR(d_date) AS year_number
FROM date_seq;


-- =============================================================================
-- STEP 2: POPULATE CUSTOMER DIMENSION (dim_customers)
-- Includes Brazilian macro-region classification
-- =============================================================================
TRUNCATE TABLE dim_customers;

INSERT INTO dim_customers (
    customer_id,
    customer_unique_id,
    zip_code_prefix,
    city,
    state,
    region
)
SELECT 
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix AS zip_code_prefix,
    TRIM(LOWER(customer_city)) AS city,
    UPPER(TRIM(customer_state)) AS state,
    CASE 
        WHEN UPPER(TRIM(customer_state)) IN ('SP', 'RJ', 'MG', 'ES') THEN 'Southeast'
        WHEN UPPER(TRIM(customer_state)) IN ('PR', 'SC', 'RS') THEN 'South'
        WHEN UPPER(TRIM(customer_state)) IN ('BA', 'PE', 'CE', 'MA', 'PB', 'RN', 'AL', 'SE', 'PI') THEN 'Northeast'
        WHEN UPPER(TRIM(customer_state)) IN ('MT', 'MS', 'GO', 'DF') THEN 'Central-West'
        WHEN UPPER(TRIM(customer_state)) IN ('AM', 'PA', 'RO', 'TO', 'AC', 'AP', 'RR') THEN 'North'
        ELSE 'Other'
    END AS region
FROM raw_customers;


-- =============================================================================
-- STEP 3: POPULATE PRODUCT DIMENSION (dim_products)
-- Translates categories from Portuguese to English and handles missing values
-- =============================================================================
TRUNCATE TABLE dim_products;

INSERT INTO dim_products (
    product_id,
    category_name_pt,
    category_name_en,
    name_length,
    description_length,
    photos_qty,
    weight_g,
    length_cm,
    height_cm,
    width_cm,
    volume_cm3
)
SELECT 
    p.product_id,
    COALESCE(p.product_category_name, 'desconhecido') AS category_name_pt,
    COALESCE(t.product_category_name_english, 
        CASE 
            WHEN p.product_category_name IS NULL OR TRIM(p.product_category_name) = '' THEN 'Unknown'
            ELSE REPLACE(p.product_category_name, '_', ' ')
        END
    ) AS category_name_en,
    p.product_name_lenght AS name_length,
    p.product_description_lenght AS description_length,
    p.product_photos_qty AS photos_qty,
    p.product_weight_g AS weight_g,
    p.product_length_cm AS length_cm,
    p.product_height_cm AS height_cm,
    p.product_width_cm AS width_cm,
    ROUND((COALESCE(p.product_length_cm, 0) * COALESCE(p.product_height_cm, 0) * COALESCE(p.product_width_cm, 0)), 2) AS volume_cm3
FROM raw_products p
LEFT JOIN raw_category_translation t 
    ON p.product_category_name = t.product_category_name;


-- =============================================================================
-- STEP 4: POPULATE SELLER DIMENSION (dim_sellers)
-- =============================================================================
TRUNCATE TABLE dim_sellers;

INSERT INTO dim_sellers (
    seller_id,
    zip_code_prefix,
    city,
    state,
    region
)
SELECT 
    seller_id,
    seller_zip_code_prefix AS zip_code_prefix,
    TRIM(LOWER(seller_city)) AS city,
    UPPER(TRIM(seller_state)) AS state,
    CASE 
        WHEN UPPER(TRIM(seller_state)) IN ('SP', 'RJ', 'MG', 'ES') THEN 'Southeast'
        WHEN UPPER(TRIM(seller_state)) IN ('PR', 'SC', 'RS') THEN 'South'
        WHEN UPPER(TRIM(seller_state)) IN ('BA', 'PE', 'CE', 'MA', 'PB', 'RN', 'AL', 'SE', 'PI') THEN 'Northeast'
        WHEN UPPER(TRIM(seller_state)) IN ('MT', 'MS', 'GO', 'DF') THEN 'Central-West'
        WHEN UPPER(TRIM(seller_state)) IN ('AM', 'PA', 'RO', 'TO', 'AC', 'AP', 'RR') THEN 'North'
        ELSE 'Other'
    END AS region
FROM raw_sellers;


-- =============================================================================
-- STEP 5: POPULATE ORDERS FACT (fact_orders)
-- Calculates logistical delivery performance metrics and latency
-- =============================================================================
TRUNCATE TABLE fact_orders;

INSERT INTO fact_orders (
    order_id,
    customer_id,
    order_status,
    purchase_date,
    purchase_timestamp,
    approved_at,
    delivered_carrier_date,
    delivered_customer_date,
    estimated_delivery_date,
    delivery_lead_time_days,
    delivery_vs_estimated_days,
    delivery_status
)
SELECT 
    o.order_id,
    o.customer_id,
    o.order_status,
    CAST(o.order_purchase_timestamp AS DATE) AS purchase_date,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    CASE 
        WHEN o.order_delivered_customer_date IS NOT NULL 
        THEN ROUND(TIMESTAMPDIFF(SECOND, o.order_purchase_timestamp, o.order_delivered_customer_date) / 86400.0, 2)
        ELSE NULL 
    END AS delivery_lead_time_days,
    CASE 
        WHEN o.order_delivered_customer_date IS NOT NULL 
        THEN ROUND(TIMESTAMPDIFF(SECOND, o.order_estimated_delivery_date, o.order_delivered_customer_date) / 86400.0, 2)
        ELSE NULL 
    END AS delivery_vs_estimated_days,
    CASE 
        WHEN o.order_delivered_customer_date IS NULL THEN 'Undelivered'
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
        ELSE 'On-Time'
    END AS delivery_status
FROM raw_orders o
WHERE CAST(o.order_purchase_timestamp AS DATE) BETWEEN '2016-01-01' AND '2018-12-31';


-- =============================================================================
-- STEP 6: POPULATE ORDER ITEMS FACT (fact_order_items)
-- =============================================================================
TRUNCATE TABLE fact_order_items;

INSERT INTO fact_order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    purchase_date,
    shipping_limit_date,
    price,
    freight_value,
    total_item_value
)
SELECT 
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    fo.purchase_date,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    ROUND(oi.price + oi.freight_value, 2) AS total_item_value
FROM raw_order_items oi
INNER JOIN fact_orders fo ON oi.order_id = fo.order_id;


-- =============================================================================
-- STEP 7: POPULATE PAYMENTS FACT (fact_payments)
-- =============================================================================
TRUNCATE TABLE fact_payments;

INSERT INTO fact_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT 
    p.order_id,
    p.payment_sequential,
    p.payment_type,
    p.payment_installments,
    p.payment_value
FROM raw_order_payments p
INNER JOIN fact_orders fo ON p.order_id = fo.order_id;


-- =============================================================================
-- STEP 8: POPULATE REVIEWS FACT (fact_reviews)
-- =============================================================================
TRUNCATE TABLE fact_reviews;

INSERT INTO fact_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    review_response_time_hours
)
SELECT 
    r.review_id,
    r.order_id,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    r.review_creation_date,
    r.review_answer_timestamp,
    ROUND(TIMESTAMPDIFF(SECOND, r.review_creation_date, r.review_answer_timestamp) / 3600.0, 2) AS review_response_time_hours
FROM raw_order_reviews r
INNER JOIN fact_orders fo ON r.order_id = fo.order_id;
