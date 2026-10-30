-- =============================================================================
-- E-COMMERCE 360° BUSINESS INTELLIGENCE PLATFORM
-- Script 06: Customer Analytics & Segmentation
-- DBMS: MySQL 8.0+
-- Queries 8 to 14
-- =============================================================================

USE ecommerce_analytics;

-- =============================================================================
-- QUERY 8: Repeat Customer Rate & Order Distribution
-- Business Question: What percentage of unique customers make more than one purchase?
-- =============================================================================
WITH customer_order_counts AS (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT fo.order_id) AS orders_count,
        ROUND(SUM(foi.price), 2) AS total_customer_spend
    FROM fact_orders fo
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT 
    COUNT(*) AS total_unique_customers,
    SUM(CASE WHEN orders_count = 1 THEN 1 ELSE 0 END) AS one_time_buyers,
    SUM(CASE WHEN orders_count > 1 THEN 1 ELSE 0 END) AS repeat_buyers,
    ROUND(100.0 * SUM(CASE WHEN orders_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_buyer_rate_pct,
    ROUND(AVG(total_customer_spend), 2) AS overall_avg_spend,
    ROUND(AVG(CASE WHEN orders_count > 1 THEN total_customer_spend END), 2) AS repeat_buyer_avg_spend
FROM customer_order_counts;


-- =============================================================================
-- QUERY 9: Customer Purchase Ranking by Spend
-- Technical Feature: DENSE_RANK() Window Function
-- Business Question: Who are our highest spending customers across all orders?
-- =============================================================================
WITH customer_lifetime_spend AS (
    SELECT 
        c.customer_unique_id,
        c.state AS primary_state,
        COUNT(DISTINCT fo.order_id) AS total_orders,
        ROUND(SUM(foi.price), 2) AS total_item_spend,
        ROUND(SUM(foi.freight_value), 2) AS total_freight_paid,
        ROUND(SUM(foi.total_item_value), 2) AS total_gross_spend
    FROM fact_orders fo
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.state
)
SELECT 
    customer_unique_id,
    primary_state,
    total_orders,
    total_item_spend,
    total_freight_paid,
    total_gross_spend,
    DENSE_RANK() OVER (ORDER BY total_item_spend DESC) AS spend_rank
FROM customer_lifetime_spend
ORDER BY spend_rank
LIMIT 25;


-- =============================================================================
-- QUERY 10: SQL-Based RFM Metrics Computation
-- Recency (days since last purchase relative to dataset reference date 2018-09-03)
-- Frequency (count of distinct delivered orders)
-- Monetary (total product revenue contributed)
-- =============================================================================
WITH dataset_anchor AS (
    SELECT MAX(purchase_date) AS max_order_date FROM fact_orders WHERE order_status = 'delivered'
),
customer_rfm_raw AS (
    SELECT 
        c.customer_unique_id,
        DATEDIFF(a.max_order_date, MAX(fo.purchase_date)) AS recency_days,
        COUNT(DISTINCT fo.order_id) AS frequency,
        ROUND(SUM(foi.price), 2) AS monetary
    FROM fact_orders fo
    CROSS JOIN dataset_anchor a
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY c.customer_unique_id, a.max_order_date
)
SELECT 
    customer_unique_id,
    recency_days,
    frequency,
    monetary
FROM customer_rfm_raw
ORDER BY monetary DESC
LIMIT 20;


-- =============================================================================
-- QUERY 11: SQL RFM Customer Segmentation
-- Technical Feature: NTILE(5) Window Functions & CASE WHEN Business Rule Engine
-- Business Question: What is the customer count and revenue share per segment?
-- =============================================================================
WITH dataset_anchor AS (
    SELECT MAX(purchase_date) AS max_order_date FROM fact_orders WHERE order_status = 'delivered'
),
rfm_base AS (
    SELECT 
        c.customer_unique_id,
        DATEDIFF(a.max_order_date, MAX(fo.purchase_date)) AS recency,
        COUNT(DISTINCT fo.order_id) AS frequency,
        SUM(foi.price) AS monetary
    FROM fact_orders fo
    CROSS JOIN dataset_anchor a
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY c.customer_unique_id, a.max_order_date
),
rfm_scores AS (
    SELECT 
        customer_unique_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score, -- Higher score = more recent
        CASE WHEN frequency > 1 THEN 5 ELSE 1 END AS f_score, -- Frequency skewed towards 1 order
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score   -- Higher score = higher spend
    FROM rfm_base
),
rfm_segmented AS (
    SELECT 
        customer_unique_id,
        recency,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        CASE 
            WHEN r_score >= 4 AND f_score = 5 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score = 5 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score = 1 AND m_score >= 3 THEN 'Potential Loyalists'
            WHEN r_score >= 3 AND f_score = 1 THEN 'Recent Customers'
            WHEN r_score <= 2 AND f_score = 5 THEN 'At Risk'
            WHEN r_score <= 2 AND m_score >= 4 THEN 'Can\'t Lose Them'
            ELSE 'Hibernating / Inactive'
        END AS customer_segment
    FROM rfm_scores
)
SELECT 
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_pct,
    ROUND(SUM(monetary), 2) AS total_segment_revenue,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS revenue_share_pct,
    ROUND(AVG(recency), 1) AS avg_recency_days,
    ROUND(AVG(monetary), 2) AS avg_monetary_spend
FROM rfm_segmented
GROUP BY customer_segment
ORDER BY total_segment_revenue DESC;


-- =============================================================================
-- QUERY 12: Customer Lifetime Value (CLV) Decile Segmentation
-- Technical Feature: NTILE(10) Window Function
-- Business Question: How concentrated is revenue across customer deciles?
-- =============================================================================
WITH customer_revenue AS (
    SELECT 
        c.customer_unique_id,
        SUM(foi.price) AS lifetime_spend
    FROM fact_orders fo
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_deciles AS (
    SELECT 
        customer_unique_id,
        lifetime_spend,
        NTILE(10) OVER (ORDER BY lifetime_spend DESC) AS spend_decile
    FROM customer_revenue
)
SELECT 
    spend_decile,
    COUNT(*) AS customer_count,
    ROUND(MIN(lifetime_spend), 2) AS min_spend,
    ROUND(MAX(lifetime_spend), 2) AS max_spend,
    ROUND(SUM(lifetime_spend), 2) AS decile_revenue,
    ROUND(100.0 * SUM(lifetime_spend) / SUM(SUM(lifetime_spend)) OVER (), 2) AS revenue_pct
FROM customer_deciles
GROUP BY spend_decile
ORDER BY spend_decile ASC;


-- =============================================================================
-- QUERY 13: Time Between Successive Orders for Repeat Customers
-- Technical Feature: LAG() Window Function partitioned by customer
-- Business Question: What is the average reorder cycle for returning buyers?
-- =============================================================================
WITH customer_order_timeline AS (
    SELECT 
        c.customer_unique_id,
        fo.order_id,
        fo.purchase_date,
        LAG(fo.purchase_date, 1) OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY fo.purchase_date, fo.purchase_timestamp
        ) AS prior_order_date
    FROM fact_orders fo
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    WHERE fo.order_status = 'delivered'
)
SELECT 
    ROUND(AVG(DATEDIFF(purchase_date, prior_order_date)), 1) AS avg_days_between_orders,
    ROUND(MIN(DATEDIFF(purchase_date, prior_order_date)), 1) AS min_days_between_orders,
    ROUND(MAX(DATEDIFF(purchase_date, prior_order_date)), 1) AS max_days_between_orders,
    COUNT(*) AS total_repeat_transactions
FROM customer_order_timeline
WHERE prior_order_date IS NOT NULL;


-- =============================================================================
-- QUERY 14: Top 15 Customer Cities by Revenue & Customer Base
-- Business Question: In which cities should local fulfillment hubs be prioritized?
-- =============================================================================
SELECT 
    c.city,
    c.state,
    c.region,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(DISTINCT fo.order_id) AS total_orders,
    ROUND(SUM(foi.price), 2) AS total_revenue,
    ROUND(SUM(foi.price) / COUNT(DISTINCT fo.order_id), 2) AS avg_order_value
FROM fact_orders fo
JOIN dim_customers c ON fo.customer_id = c.customer_id
JOIN fact_order_items foi ON fo.order_id = foi.order_id
WHERE fo.order_status = 'delivered'
GROUP BY c.city, c.state, c.region
ORDER BY total_revenue DESC
LIMIT 15;
