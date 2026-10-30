-- =============================================================================
-- E-COMMERCE 360° BUSINESS INTELLIGENCE PLATFORM
-- Script 09: Advanced Analytics, Cohort Retention & Power BI Curated Views
-- DBMS: MySQL 8.0+
-- Queries 29 to 35
-- =============================================================================

USE ecommerce_analytics;

-- =============================================================================
-- QUERY 29: Customer Cohort Retention Matrix (Pure SQL)
-- Technical Feature: Complex Multi-Step CTEs, Window Functions & Conditional Aggregation
-- Business Question: What percentage of newly acquired customers return in subsequent months?
-- =============================================================================
WITH customer_first_purchase AS (
    -- 1. Identify initial acquisition month for each unique customer
    SELECT 
        c.customer_unique_id,
        MIN(d.year_month) AS cohort_month,
        MIN(fo.purchase_date) AS first_purchase_date
    FROM fact_orders fo
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    JOIN dim_date d ON fo.purchase_date = d.date_key
    WHERE fo.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
customer_activities AS (
    -- 2. Trace all subsequent order activities
    SELECT 
        c.customer_unique_id,
        fp.cohort_month,
        d.year_month AS activity_month,
        PERIOD_DIFF(
            DATE_FORMAT(d.date_key, '%Y%m'),
            DATE_FORMAT(fp.first_purchase_date, '%Y%m')
        ) AS month_number
    FROM fact_orders fo
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    JOIN dim_date d ON fo.purchase_date = d.date_key
    JOIN customer_first_purchase fp ON c.customer_unique_id = fp.customer_unique_id
    WHERE fo.order_status = 'delivered'
    GROUP BY c.customer_unique_id, fp.cohort_month, d.year_month, fp.first_purchase_date
),
cohort_size AS (
    -- 3. Base size for each acquisition cohort
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_unique_id) AS cohort_users
    FROM customer_first_purchase
    GROUP BY cohort_month
)
SELECT 
    ca.cohort_month,
    cs.cohort_users AS m0_users,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 1 THEN ca.customer_unique_id END) / cs.cohort_users, 2) AS m1_retention_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 2 THEN ca.customer_unique_id END) / cs.cohort_users, 2) AS m2_retention_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 3 THEN ca.customer_unique_id END) / cs.cohort_users, 2) AS m3_retention_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 4 THEN ca.customer_unique_id END) / cs.cohort_users, 2) AS m4_retention_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 5 THEN ca.customer_unique_id END) / cs.cohort_users, 2) AS m5_retention_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ca.month_number = 6 THEN ca.customer_unique_id END) / cs.cohort_users, 2) AS m6_retention_pct
FROM customer_activities ca
JOIN cohort_size cs ON ca.cohort_month = cs.cohort_month
WHERE ca.cohort_month BETWEEN '2017-01' AND '2018-03'
GROUP BY ca.cohort_month, cs.cohort_users
ORDER BY ca.cohort_month;


-- =============================================================================
-- QUERY 30: 3-Month Moving Average of Revenue & Growth Smoothing
-- Technical Feature: AVG() OVER (ORDER BY ... ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
-- Business Question: What is the smoothed baseline growth filtering out short-term spikes?
-- =============================================================================
WITH monthly_metrics AS (
    SELECT 
        d.year_month,
        ROUND(SUM(foi.price), 2) AS monthly_revenue,
        COUNT(DISTINCT fo.order_id) AS monthly_orders
    FROM fact_orders fo
    JOIN dim_date d ON fo.purchase_date = d.date_key
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY d.year_month
)
SELECT 
    year_month,
    monthly_revenue,
    monthly_orders,
    ROUND(AVG(monthly_revenue) OVER (
        ORDER BY year_month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS revenue_3m_moving_avg,
    ROUND(AVG(monthly_orders) OVER (
        ORDER BY year_month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0) AS orders_3m_moving_avg
FROM monthly_metrics
ORDER BY year_month;


-- =============================================================================
-- QUERY 31: Customer Spend Pareto 80/20 Rule Analysis
-- Technical Feature: Running Total Window Functions & Cumulative Percentage
-- Business Question: What exact percentage of unique customers drive 80% of revenue?
-- =============================================================================
WITH customer_totals AS (
    SELECT 
        c.customer_unique_id,
        SUM(foi.price) AS total_spend
    FROM fact_orders fo
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
ranked_customers AS (
    SELECT 
        customer_unique_id,
        total_spend,
        ROW_NUMBER() OVER (ORDER BY total_spend DESC) AS customer_rank,
        COUNT(*) OVER () AS total_customer_population,
        SUM(total_spend) OVER (ORDER BY total_spend DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_spend,
        SUM(total_spend) OVER () AS grand_total_spend
    FROM customer_totals
)
SELECT 
    CASE 
        WHEN (100.0 * running_spend / grand_total_spend) <= 80.0 THEN 'Top 80% Spend Tier'
        ELSE 'Remaining 20% Spend Tier'
    END AS revenue_bracket,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / MAX(total_customer_population), 2) AS pct_of_customers,
    ROUND(SUM(total_spend), 2) AS bracket_revenue,
    ROUND(100.0 * SUM(total_spend) / MAX(grand_total_spend), 2) AS pct_of_total_revenue
FROM ranked_customers
GROUP BY 
    CASE 
        WHEN (100.0 * running_spend / grand_total_spend) <= 80.0 THEN 'Top 80% Spend Tier'
        ELSE 'Remaining 20% Spend Tier'
    END;


-- =============================================================================
-- QUERY 32: Seller Performance Quartiles
-- Technical Feature: NTILE(4) Window Function
-- Business Question: How do sales and delivery metrics compare between seller tiers?
-- =============================================================================
WITH seller_aggregates AS (
    SELECT 
        s.seller_id,
        COUNT(DISTINCT fo.order_id) AS orders_fulfilled,
        ROUND(SUM(foi.price), 2) AS total_revenue,
        ROUND(AVG(fo.delivery_lead_time_days), 1) AS avg_delivery_days,
        ROUND(AVG(r.review_score), 2) AS avg_rating
    FROM fact_orders fo
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    JOIN dim_sellers s ON foi.seller_id = s.seller_id
    LEFT JOIN fact_reviews r ON fo.order_id = r.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY s.seller_id
),
seller_quartiles AS (
    SELECT 
        seller_id,
        orders_fulfilled,
        total_revenue,
        avg_delivery_days,
        avg_rating,
        NTILE(4) OVER (ORDER BY total_revenue DESC) AS seller_tier -- Tier 1 = Top 25%
    FROM seller_aggregates
)
SELECT 
    seller_tier,
    CASE 
        WHEN seller_tier = 1 THEN 'Tier 1 - Platinum Sellers'
        WHEN seller_tier = 2 THEN 'Tier 2 - Gold Sellers'
        WHEN seller_tier = 3 THEN 'Tier 3 - Silver Sellers'
        ELSE 'Tier 4 - Bronze Sellers'
    END AS tier_name,
    COUNT(*) AS seller_count,
    ROUND(SUM(total_revenue), 2) AS tier_revenue,
    ROUND(100.0 * SUM(total_revenue) / SUM(SUM(total_revenue)) OVER (), 2) AS revenue_share_pct,
    ROUND(AVG(orders_fulfilled), 1) AS avg_orders_per_seller,
    ROUND(AVG(avg_delivery_days), 1) AS avg_delivery_transit_days,
    ROUND(AVG(avg_rating), 2) AS avg_seller_rating
FROM seller_quartiles
GROUP BY seller_tier, tier_name
ORDER BY seller_tier;


-- =============================================================================
-- QUERY 33: Multi-Category Basket Affinity (Cross-Category Purchasing)
-- Business Question: Which product categories are frequently bought together in single orders?
-- =============================================================================
WITH order_category_pairs AS (
    SELECT 
        foi1.order_id,
        p1.category_name_en AS category_a,
        p2.category_name_en AS category_b
    FROM fact_order_items foi1
    JOIN fact_order_items foi2 
        ON foi1.order_id = foi2.order_id AND foi1.product_id < foi2.product_id
    JOIN dim_products p1 ON foi1.product_id = p1.product_id
    JOIN dim_products p2 ON foi2.product_id = p2.product_id
    WHERE p1.category_name_en <> p2.category_name_en
)
SELECT 
    category_a,
    category_b,
    COUNT(DISTINCT order_id) AS co_purchase_orders_count
FROM order_category_pairs
GROUP BY category_a, category_b
ORDER BY co_purchase_orders_count DESC
LIMIT 15;


-- =============================================================================
-- QUERY 34: Power BI Semantic Reporting View (Order Grain)
-- Purpose: Pre-aggregates metrics to order level to eliminate fan-out row multiplication
-- =============================================================================
CREATE OR REPLACE VIEW view_powerbi_orders AS
SELECT 
    fo.order_id,
    fo.customer_id,
    c.customer_unique_id,
    c.city AS customer_city,
    c.state AS customer_state,
    c.region AS customer_region,
    fo.order_status,
    fo.purchase_date,
    d.year_month,
    d.year_quarter,
    d.year_number,
    d.month_name,
    d.day_name,
    d.is_weekend,
    fo.delivery_status,
    fo.delivery_lead_time_days,
    fo.delivery_vs_estimated_days,
    COALESCE(oi_agg.total_item_revenue, 0) AS total_item_revenue,
    COALESCE(oi_agg.total_freight_value, 0) AS total_freight_value,
    COALESCE(oi_agg.total_order_value, 0) AS total_order_value,
    COALESCE(oi_agg.item_count, 0) AS item_count,
    COALESCE(pay_agg.total_payment_value, 0) AS total_payment_value,
    pay_agg.primary_payment_type,
    rev_agg.review_score,
    rev_agg.has_review
FROM fact_orders fo
JOIN dim_customers c ON fo.customer_id = c.customer_id
JOIN dim_date d ON fo.purchase_date = d.date_key
LEFT JOIN (
    SELECT 
        order_id,
        COUNT(order_item_surrogate_id) AS item_count,
        ROUND(SUM(price), 2) AS total_item_revenue,
        ROUND(SUM(freight_value), 2) AS total_freight_value,
        ROUND(SUM(total_item_value), 2) AS total_order_value
    FROM fact_order_items
    GROUP BY order_id
) oi_agg ON fo.order_id = oi_agg.order_id
LEFT JOIN (
    SELECT 
        order_id,
        ROUND(SUM(payment_value), 2) AS total_payment_value,
        SUBSTRING_INDEX(GROUP_CONCAT(payment_type ORDER BY payment_value DESC), ',', 1) AS primary_payment_type
    FROM fact_payments
    GROUP BY order_id
) pay_agg ON fo.order_id = pay_agg.order_id
LEFT JOIN (
    SELECT 
        order_id,
        AVG(review_score) AS review_score,
        1 AS has_review
    FROM fact_reviews
    GROUP BY order_id
) rev_agg ON fo.order_id = rev_agg.order_id;


-- =============================================================================
-- QUERY 35: Power BI Customer RFM Analytics View
-- Purpose: Exposes ready-to-use customer RFM segments directly to Power BI
-- =============================================================================
CREATE OR REPLACE VIEW view_powerbi_customer_rfm AS
WITH dataset_anchor AS (
    SELECT MAX(purchase_date) AS max_order_date FROM fact_orders WHERE order_status = 'delivered'
),
rfm_raw AS (
    SELECT 
        c.customer_unique_id,
        MAX(c.state) AS customer_state,
        MAX(c.region) AS customer_region,
        DATEDIFF(a.max_order_date, MAX(fo.purchase_date)) AS recency,
        COUNT(DISTINCT fo.order_id) AS frequency,
        ROUND(SUM(foi.price), 2) AS monetary
    FROM fact_orders fo
    CROSS JOIN dataset_anchor a
    JOIN dim_customers c ON fo.customer_id = c.customer_id
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY c.customer_unique_id, a.max_order_date
),
rfm_scored AS (
    SELECT 
        customer_unique_id,
        customer_state,
        customer_region,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        CASE WHEN frequency > 1 THEN 5 ELSE 1 END AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_raw
)
SELECT 
    customer_unique_id,
    customer_state,
    customer_region,
    recency,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_combined_code,
    CASE 
        WHEN r_score >= 4 AND f_score = 5 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score = 5 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score = 1 AND m_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score >= 3 AND f_score = 1 THEN 'Recent Customers'
        WHEN r_score <= 2 AND f_score = 5 THEN 'At Risk'
        WHEN r_score <= 2 AND m_score >= 4 THEN 'Can\'t Lose Them'
        ELSE 'Hibernating / Inactive'
    END AS segment_name
FROM rfm_scored;
