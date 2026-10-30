-- =============================================================================
-- E-COMMERCE 360° BUSINESS INTELLIGENCE PLATFORM
-- Script 05: Sales & Revenue Performance Analysis
-- DBMS: MySQL 8.0+
-- Queries 1 to 7
-- =============================================================================

USE ecommerce_analytics;

-- =============================================================================
-- QUERY 1: Monthly Revenue, Freight, and Order Volume Trend
-- Business Question: How is the overall business scaling month over month?
-- Note: Filters for delivered orders to represent realized net sales.
-- =============================================================================
SELECT 
    d.year_month AS sales_month,
    COUNT(DISTINCT fo.order_id) AS total_orders,
    COUNT(foi.order_item_surrogate_id) AS total_items_sold,
    ROUND(SUM(foi.price), 2) AS total_item_revenue,
    ROUND(SUM(foi.freight_value), 2) AS total_freight_value,
    ROUND(SUM(foi.total_item_value), 2) AS gross_merchandise_value,
    ROUND(SUM(foi.price) / COUNT(DISTINCT fo.order_id), 2) AS average_order_value
FROM fact_orders fo
JOIN dim_date d ON fo.purchase_date = d.date_key
JOIN fact_order_items foi ON fo.order_id = foi.order_id
WHERE fo.order_status = 'delivered'
GROUP BY d.year_month
ORDER BY d.year_month;


-- =============================================================================
-- QUERY 2: Month-over-Month (MoM) Revenue Growth Rate (%)
-- Technical Feature: LAG() Window Function over Time-Series
-- Business Question: Which months experienced acceleration or contraction in sales?
-- =============================================================================
WITH monthly_sales AS (
    SELECT 
        d.year_month,
        ROUND(SUM(foi.price), 2) AS current_month_revenue,
        COUNT(DISTINCT fo.order_id) AS order_volume
    FROM fact_orders fo
    JOIN dim_date d ON fo.purchase_date = d.date_key
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY d.year_month
)
SELECT 
    year_month,
    order_volume,
    current_month_revenue,
    LAG(current_month_revenue, 1) OVER (ORDER BY year_month) AS prior_month_revenue,
    ROUND(
        (current_month_revenue - LAG(current_month_revenue, 1) OVER (ORDER BY year_month)) /
        LAG(current_month_revenue, 1) OVER (ORDER BY year_month) * 100.0,
        2
    ) AS mom_revenue_growth_pct
FROM monthly_sales
ORDER BY year_month;


-- =============================================================================
-- QUERY 3: Quarterly Sales Performance & Cumulative Running Revenue
-- Technical Feature: SUM() OVER (ORDER BY ...) Running Total Window Function
-- Business Question: What is the cumulative revenue trajectory per quarter?
-- =============================================================================
WITH quarterly_summary AS (
    SELECT 
        d.year_quarter,
        COUNT(DISTINCT fo.order_id) AS quarterly_orders,
        ROUND(SUM(foi.price), 2) AS quarterly_revenue
    FROM fact_orders fo
    JOIN dim_date d ON fo.purchase_date = d.date_key
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY d.year_quarter
)
SELECT 
    year_quarter,
    quarterly_orders,
    quarterly_revenue,
    ROUND(SUM(quarterly_revenue) OVER (ORDER BY year_quarter ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS cumulative_revenue
FROM quarterly_summary
ORDER BY year_quarter;


-- =============================================================================
-- QUERY 4: Revenue & Order Contribution by Customer State
-- Business Question: What are the primary geographic revenue drivers across Brazil?
-- =============================================================================
SELECT 
    c.state AS customer_state,
    c.region AS macro_region,
    COUNT(DISTINCT fo.order_id) AS total_orders,
    ROUND(SUM(foi.price), 2) AS state_revenue,
    ROUND(100.0 * SUM(foi.price) / SUM(SUM(foi.price)) OVER (), 2) AS revenue_share_pct,
    ROUND(AVG(foi.price), 2) AS avg_item_price,
    ROUND(AVG(foi.freight_value), 2) AS avg_freight_cost
FROM fact_orders fo
JOIN dim_customers c ON fo.customer_id = c.customer_id
JOIN fact_order_items foi ON fo.order_id = foi.order_id
WHERE fo.order_status = 'delivered'
GROUP BY c.state, c.region
ORDER BY state_revenue DESC;


-- =============================================================================
-- QUERY 5: Macro-Region Performance & Logistics Friction Analysis
-- Business Question: Does high freight ratio restrict regional growth outside Southeast?
-- =============================================================================
SELECT 
    c.region AS macro_region,
    COUNT(DISTINCT fo.order_id) AS total_orders,
    ROUND(SUM(foi.price), 2) AS product_revenue,
    ROUND(SUM(foi.freight_value), 2) AS freight_revenue,
    ROUND(100.0 * SUM(foi.freight_value) / SUM(foi.price), 2) AS freight_to_price_ratio_pct,
    ROUND(AVG(fo.delivery_lead_time_days), 1) AS avg_lead_time_days
FROM fact_orders fo
JOIN dim_customers c ON fo.customer_id = c.customer_id
JOIN fact_order_items foi ON fo.order_id = foi.order_id
WHERE fo.order_status = 'delivered'
GROUP BY c.region
ORDER BY product_revenue DESC;


-- =============================================================================
-- QUERY 6: Payment Method Adoption, Value Distribution & Installment Behavior
-- Business Question: Which payment channels dominate, and what is the financing profile?
-- =============================================================================
SELECT 
    payment_type,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(100.0 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 2) AS payment_value_share_pct,
    ROUND(AVG(payment_value), 2) AS avg_transaction_value,
    ROUND(AVG(payment_installments), 1) AS avg_installments
FROM fact_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;


-- =============================================================================
-- QUERY 7: Temporal Shopping Patterns (Hour of Day and Day of Week)
-- Business Question: When should promotional marketing and flash sales be scheduled?
-- =============================================================================
SELECT 
    d.day_name,
    d.day_of_week,
    HOUR(fo.purchase_timestamp) AS purchase_hour,
    COUNT(DISTINCT fo.order_id) AS order_count,
    ROUND(SUM(foi.price), 2) AS total_revenue
FROM fact_orders fo
JOIN dim_date d ON fo.purchase_date = d.date_key
JOIN fact_order_items foi ON fo.order_id = foi.order_id
WHERE fo.order_status = 'delivered'
GROUP BY d.day_name, d.day_of_week, purchase_hour
ORDER BY order_count DESC
LIMIT 20;
