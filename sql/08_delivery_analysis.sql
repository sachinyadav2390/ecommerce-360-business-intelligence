-- =============================================================================
-- E-COMMERCE 360° BUSINESS INTELLIGENCE PLATFORM
-- Script 08: Logistics, Delivery Performance & Seller Efficiency
-- DBMS: MySQL 8.0+
-- Queries 22 to 28
-- =============================================================================

USE ecommerce_analytics;

-- =============================================================================
-- QUERY 22: Overall Delivery SLA Compliance Benchmark
-- Business Question: What proportion of delivered orders met the estimated SLA?
-- =============================================================================
SELECT 
    COUNT(*) AS total_delivered_orders,
    SUM(CASE WHEN delivery_status = 'On-Time' THEN 1 ELSE 0 END) AS on_time_deliveries,
    SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) AS late_deliveries,
    ROUND(100.0 * SUM(CASE WHEN delivery_status = 'On-Time' THEN 1 ELSE 0 END) / COUNT(*), 2) AS on_time_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN delivery_status = 'Late' THEN 1 ELSE 0 END) / COUNT(*), 2) AS late_rate_pct,
    ROUND(AVG(delivery_lead_time_days), 1) AS avg_lead_time_days,
    ROUND(AVG(delivery_vs_estimated_days), 1) AS avg_days_vs_estimate -- Negative = arrived ahead of estimate
FROM fact_orders
WHERE order_status = 'delivered' AND delivered_customer_date IS NOT NULL;


-- =============================================================================
-- QUERY 23: Monthly Delivery Lead Time & Delay Rate Trend
-- Business Question: Has logistical efficiency improved or degraded over time?
-- =============================================================================
SELECT 
    d.year_month,
    COUNT(fo.order_id) AS total_delivered_orders,
    ROUND(AVG(fo.delivery_lead_time_days), 1) AS avg_delivery_days,
    ROUND(AVG(fo.delivery_vs_estimated_days), 1) AS avg_days_ahead_or_late,
    SUM(CASE WHEN fo.delivery_status = 'Late' THEN 1 ELSE 0 END) AS late_deliveries,
    ROUND(100.0 * SUM(CASE WHEN fo.delivery_status = 'Late' THEN 1 ELSE 0 END) / COUNT(fo.order_id), 2) AS late_delivery_pct
FROM fact_orders fo
JOIN dim_date d ON fo.purchase_date = d.date_key
WHERE fo.order_status = 'delivered' AND fo.delivered_customer_date IS NOT NULL
GROUP BY d.year_month
ORDER BY d.year_month;


-- =============================================================================
-- QUERY 24: Direct Correlation: Delivery Lead Time vs Review Ratings
-- Business Question: How sharply does customer satisfaction drop as delivery days increase?
-- =============================================================================
SELECT 
    CASE 
        WHEN fo.delivery_lead_time_days <= 3 THEN '01. Rapid (<= 3 days)'
        WHEN fo.delivery_lead_time_days <= 7 THEN '02. Express (4-7 days)'
        WHEN fo.delivery_lead_time_days <= 14 THEN '03. Standard (8-14 days)'
        WHEN fo.delivery_lead_time_days <= 21 THEN '04. Moderate (15-21 days)'
        WHEN fo.delivery_lead_time_days <= 30 THEN '05. Delayed (22-30 days)'
        ELSE '06. Severe Delay (> 30 days)'
    END AS delivery_speed_tier,
    COUNT(DISTINCT fo.order_id) AS orders_count,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END) / COUNT(r.review_score), 2) AS five_star_pct,
    ROUND(100.0 * SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(r.review_score), 2) AS one_star_pct
FROM fact_orders fo
JOIN fact_reviews r ON fo.order_id = r.order_id
WHERE fo.order_status = 'delivered' AND fo.delivery_lead_time_days IS NOT NULL
GROUP BY delivery_speed_tier
ORDER BY delivery_speed_tier;


-- =============================================================================
-- QUERY 25: Logistics Performance by Destination State
-- Business Question: Which destination states suffer from chronic delivery bottlenecks?
-- =============================================================================
SELECT 
    c.state AS destination_state,
    c.region AS macro_region,
    COUNT(DISTINCT fo.order_id) AS total_orders,
    ROUND(AVG(fo.delivery_lead_time_days), 1) AS avg_delivery_days,
    ROUND(AVG(fo.delivery_vs_estimated_days), 1) AS avg_vs_estimate_days,
    ROUND(100.0 * SUM(CASE WHEN fo.delivery_status = 'Late' THEN 1 ELSE 0 END) / COUNT(fo.order_id), 2) AS late_delivery_pct,
    ROUND(AVG(r.review_score), 2) AS avg_state_rating
FROM fact_orders fo
JOIN dim_customers c ON fo.customer_id = c.customer_id
LEFT JOIN fact_reviews r ON fo.order_id = r.order_id
WHERE fo.order_status = 'delivered' AND fo.delivered_customer_date IS NOT NULL
GROUP BY c.state, c.region
ORDER BY avg_delivery_days DESC;


-- =============================================================================
-- QUERY 26: Seller Fulfillment Latency & Carrier Handover Delay
-- Business Question: Which sellers take longest to hand parcels to carrier dispatch?
-- =============================================================================
SELECT 
    s.seller_id,
    s.city AS seller_city,
    s.state AS seller_state,
    COUNT(DISTINCT fo.order_id) AS total_orders_fulfilled,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, fo.purchase_timestamp, fo.delivered_carrier_date) / 24.0), 1) AS avg_carrier_dispatch_days,
    ROUND(AVG(fo.delivery_lead_time_days), 1) AS avg_total_delivery_days,
    ROUND(AVG(r.review_score), 2) AS avg_seller_review_score,
    ROUND(100.0 * SUM(CASE WHEN fo.delivery_status = 'Late' THEN 1 ELSE 0 END) / COUNT(fo.order_id), 2) AS seller_late_rate_pct
FROM fact_orders fo
JOIN fact_order_items foi ON fo.order_id = foi.order_id
JOIN dim_sellers s ON foi.seller_id = s.seller_id
LEFT JOIN fact_reviews r ON fo.order_id = r.order_id
WHERE fo.order_status = 'delivered' AND fo.delivered_carrier_date IS NOT NULL
GROUP BY s.seller_id, s.city, s.state
HAVING COUNT(DISTINCT fo.order_id) >= 100
ORDER BY seller_late_rate_pct DESC
LIMIT 20;


-- =============================================================================
-- QUERY 27: Delivery Accuracy & Buffer Analysis
-- Business Question: Does Olist overestimate delivery windows to protect SLA?
-- =============================================================================
SELECT 
    CASE 
        WHEN delivery_vs_estimated_days < -10 THEN 'Very Early (>10 days ahead)'
        WHEN delivery_vs_estimated_days BETWEEN -10 AND -3 THEN 'Early (3-10 days ahead)'
        WHEN delivery_vs_estimated_days BETWEEN -2 AND 0 THEN 'On Target (0-2 days ahead)'
        WHEN delivery_vs_estimated_days BETWEEN 1 AND 5 THEN 'Slight Delay (1-5 days late)'
        ELSE 'Severe Delay (> 5 days late)'
    END AS delivery_accuracy_tier,
    COUNT(*) AS order_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total_orders,
    ROUND(AVG(delivery_lead_time_days), 1) AS avg_actual_transit_days,
    ROUND(AVG(r.review_score), 2) AS avg_rating
FROM fact_orders fo
LEFT JOIN fact_reviews r ON fo.order_id = r.order_id
WHERE fo.order_status = 'delivered' AND fo.delivery_vs_estimated_days IS NOT NULL
GROUP BY delivery_accuracy_tier
ORDER BY avg_rating DESC;


-- =============================================================================
-- QUERY 28: Cancellation & Non-Delivery Root Cause Breakdown
-- Business Question: What order statuses exist and what is the non-completion rate?
-- =============================================================================
SELECT 
    order_status,
    COUNT(order_id) AS total_orders,
    ROUND(100.0 * COUNT(order_id) / SUM(COUNT(order_id)) OVER (), 2) AS pct_of_total_orders,
    COUNT(CASE WHEN delivered_customer_date IS NOT NULL THEN 1 END) AS delivered_count
FROM fact_orders
GROUP BY order_status
ORDER BY total_orders DESC;
