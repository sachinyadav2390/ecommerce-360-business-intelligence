-- =============================================================================
-- E-COMMERCE 360° BUSINESS INTELLIGENCE PLATFORM
-- Script 07: Product & Category Analytics
-- DBMS: MySQL 8.0+
-- Queries 15 to 21
-- =============================================================================

USE ecommerce_analytics;

-- =============================================================================
-- QUERY 15: Top 10 Revenue-Generating Product Categories
-- Business Question: Which categories represent our primary product revenue engines?
-- =============================================================================
SELECT 
    p.category_name_en AS product_category,
    COUNT(DISTINCT foi.order_id) AS total_orders,
    COUNT(foi.order_item_surrogate_id) AS total_items_sold,
    ROUND(SUM(foi.price), 2) AS category_revenue,
    ROUND(100.0 * SUM(foi.price) / SUM(SUM(foi.price)) OVER (), 2) AS revenue_share_pct,
    ROUND(AVG(foi.price), 2) AS avg_item_price
FROM fact_order_items foi
JOIN fact_orders fo ON foi.order_id = fo.order_id
JOIN dim_products p ON foi.product_id = p.product_id
WHERE fo.order_status = 'delivered'
GROUP BY p.category_name_en
ORDER BY category_revenue DESC
LIMIT 10;


-- =============================================================================
-- QUERY 16: Bottom 10 Product Categories by Revenue
-- Business Question: Which categories underperform and warrant inventory re-evaluation?
-- =============================================================================
SELECT 
    p.category_name_en AS product_category,
    COUNT(DISTINCT foi.order_id) AS total_orders,
    COUNT(foi.order_item_surrogate_id) AS total_items_sold,
    ROUND(SUM(foi.price), 2) AS category_revenue,
    ROUND(AVG(foi.price), 2) AS avg_item_price
FROM fact_order_items foi
JOIN fact_orders fo ON foi.order_id = fo.order_id
JOIN dim_products p ON foi.product_id = p.product_id
WHERE fo.order_status = 'delivered'
GROUP BY p.category_name_en
ORDER BY category_revenue ASC
LIMIT 10;


-- =============================================================================
-- QUERY 17: Category Pareto Analysis (Cumulative Revenue Share)
-- Technical Feature: SUM() OVER () Window Function for Running Percentage
-- Business Question: What percentage of product categories generates 80% of revenue?
-- =============================================================================
WITH category_sales AS (
    SELECT 
        p.category_name_en AS product_category,
        ROUND(SUM(foi.price), 2) AS total_revenue
    FROM fact_order_items foi
    JOIN fact_orders fo ON foi.order_id = fo.order_id
    JOIN dim_products p ON foi.product_id = p.product_id
    WHERE fo.order_status = 'delivered'
    GROUP BY p.category_name_en
),
category_ranking AS (
    SELECT 
        product_category,
        total_revenue,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS category_rank,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS overall_total_revenue
    FROM category_sales
)
SELECT 
    category_rank,
    product_category,
    total_revenue,
    cumulative_revenue,
    ROUND(100.0 * cumulative_revenue / overall_total_revenue, 2) AS cumulative_revenue_pct,
    CASE 
        WHEN (100.0 * cumulative_revenue / overall_total_revenue) <= 80.0 THEN 'Core 80% Driver'
        ELSE 'Long Tail 20%'
    END AS pareto_classification
FROM category_ranking
ORDER BY category_rank;


-- =============================================================================
-- QUERY 18: Category Review Score & Customer Satisfaction Distribution
-- Business Question: How satisfied are customers across our major product lines?
-- =============================================================================
SELECT 
    p.category_name_en AS product_category,
    COUNT(DISTINCT foi.order_id) AS total_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) AS five_star_reviews,
    SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) AS one_star_reviews,
    ROUND(100.0 * SUM(CASE WHEN r.review_score IN (4, 5) THEN 1 ELSE 0 END) / COUNT(r.review_score), 2) AS positive_review_pct
FROM fact_order_items foi
JOIN fact_orders fo ON foi.order_id = fo.order_id
JOIN dim_products p ON foi.product_id = p.product_id
LEFT JOIN fact_reviews r ON fo.order_id = r.order_id
WHERE fo.order_status = 'delivered'
GROUP BY p.category_name_en
HAVING COUNT(DISTINCT foi.order_id) >= 100
ORDER BY avg_review_score DESC;


-- =============================================================================
-- QUERY 19: Quality Watchlist (High Sales Volume with Low Customer Satisfaction)
-- Business Question: Which top categories have dangerously low ratings (< 3.9 / 5)?
-- =============================================================================
SELECT 
    p.category_name_en AS product_category,
    COUNT(DISTINCT fo.order_id) AS total_orders,
    ROUND(SUM(foi.price), 2) AS category_revenue,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(r.review_score), 2) AS dissatisfaction_rate_pct
FROM fact_order_items foi
JOIN fact_orders fo ON foi.order_id = fo.order_id
JOIN dim_products p ON foi.product_id = p.product_id
JOIN fact_reviews r ON fo.order_id = r.order_id
WHERE fo.order_status = 'delivered'
GROUP BY p.category_name_en
HAVING COUNT(DISTINCT fo.order_id) >= 200 AND AVG(r.review_score) < 4.0
ORDER BY avg_review_score ASC;


-- =============================================================================
-- QUERY 20: Freight Cost Friction by Category (Freight-to-Price Percentage)
-- Business Question: For which categories does freight price create customer resistance?
-- =============================================================================
SELECT 
    p.category_name_en AS product_category,
    COUNT(foi.order_item_surrogate_id) AS items_sold,
    ROUND(AVG(foi.price), 2) AS avg_item_price,
    ROUND(AVG(foi.freight_value), 2) AS avg_freight,
    ROUND(AVG(p.weight_g) / 1000.0, 2) AS avg_weight_kg,
    ROUND(100.0 * SUM(foi.freight_value) / SUM(foi.price), 2) AS freight_to_price_ratio_pct
FROM fact_order_items foi
JOIN fact_orders fo ON foi.order_id = fo.order_id
JOIN dim_products p ON foi.product_id = p.product_id
WHERE fo.order_status = 'delivered'
GROUP BY p.category_name_en
HAVING COUNT(foi.order_item_surrogate_id) >= 100
ORDER BY freight_to_price_ratio_pct DESC
LIMIT 15;


-- =============================================================================
-- QUERY 21: Top 15 Best-Selling Individual Products (SKU Level)
-- Business Question: What are the superstar SKUs in terms of total units and revenue?
-- =============================================================================
SELECT 
    p.product_id,
    p.category_name_en,
    COUNT(foi.order_item_surrogate_id) AS units_sold,
    COUNT(DISTINCT foi.order_id) AS distinct_orders,
    ROUND(SUM(foi.price), 2) AS total_revenue,
    ROUND(AVG(foi.price), 2) AS avg_unit_price,
    ROUND(AVG(r.review_score), 2) AS avg_rating
FROM fact_order_items foi
JOIN fact_orders fo ON foi.order_id = fo.order_id
JOIN dim_products p ON foi.product_id = p.product_id
LEFT JOIN fact_reviews r ON fo.order_id = r.order_id
WHERE fo.order_status = 'delivered'
GROUP BY p.product_id, p.category_name_en
ORDER BY units_sold DESC
LIMIT 15;
