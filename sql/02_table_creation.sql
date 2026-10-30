-- =============================================================================
-- E-COMMERCE 360° BUSINESS INTELLIGENCE PLATFORM
-- Script 02: Table Creation (Staging Tables & Analytical Star Schema)
-- DBMS: MySQL 8.0+
-- =============================================================================

USE ecommerce_analytics;

-- =============================================================================
-- PART 1: STAGING TABLES (Raw 1:1 Ingestion Layer)
-- =============================================================================

DROP TABLE IF EXISTS raw_category_translation;
CREATE TABLE raw_category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100),
    PRIMARY KEY (product_category_name)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS raw_customers;
CREATE TABLE raw_customers (
    customer_id VARCHAR(50) NOT NULL,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_zip_code_prefix INT NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    customer_state VARCHAR(5) NOT NULL,
    PRIMARY KEY (customer_id),
    INDEX idx_cust_unique (customer_unique_id),
    INDEX idx_cust_zip (customer_zip_code_prefix)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS raw_geolocation;
CREATE TABLE raw_geolocation (
    geolocation_zip_code_prefix INT NOT NULL,
    geolocation_lat DECIMAL(10, 8),
    geolocation_lng DECIMAL(11, 8),
    geolocation_city VARCHAR(100),
    geolocation_state VARCHAR(5),
    INDEX idx_geo_zip (geolocation_zip_code_prefix)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS raw_orders;
CREATE TABLE raw_orders (
    order_id VARCHAR(50) NOT NULL,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp DATETIME NOT NULL,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NOT NULL,
    PRIMARY KEY (order_id),
    INDEX idx_orders_customer (customer_id),
    INDEX idx_orders_status (order_status),
    INDEX idx_orders_purchase (order_purchase_timestamp)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS raw_products;
CREATE TABLE raw_products (
    product_id VARCHAR(50) NOT NULL,
    product_category_name VARCHAR(100) NULL,
    product_name_lenght INT NULL,
    product_description_lenght INT NULL,
    product_photos_qty INT NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL,
    PRIMARY KEY (product_id),
    INDEX idx_prod_category (product_category_name)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS raw_sellers;
CREATE TABLE raw_sellers (
    seller_id VARCHAR(50) NOT NULL,
    seller_zip_code_prefix INT NOT NULL,
    seller_city VARCHAR(100) NOT NULL,
    seller_state VARCHAR(5) NOT NULL,
    PRIMARY KEY (seller_id),
    INDEX idx_seller_zip (seller_zip_code_prefix)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS raw_order_items;
CREATE TABLE raw_order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    freight_value DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id),
    INDEX idx_oi_product (product_id),
    INDEX idx_oi_seller (seller_id)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS raw_order_payments;
CREATE TABLE raw_order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(20) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential, payment_type),
    INDEX idx_payments_order (order_id)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS raw_order_reviews;
CREATE TABLE raw_order_reviews (
    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    review_score INT NOT NULL,
    review_comment_title VARCHAR(255) NULL,
    review_comment_message TEXT NULL,
    review_creation_date DATETIME NOT NULL,
    review_answer_timestamp DATETIME NOT NULL,
    PRIMARY KEY (review_id, order_id),
    INDEX idx_reviews_order (order_id),
    INDEX idx_reviews_score (review_score)
) ENGINE=InnoDB;


-- =============================================================================
-- PART 2: ANALYTICAL STAR SCHEMA LAYER
-- =============================================================================

DROP TABLE IF EXISTS fact_order_items;
DROP TABLE IF EXISTS fact_payments;
DROP TABLE IF EXISTS fact_reviews;
DROP TABLE IF EXISTS fact_orders;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_customers;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_sellers;

-- 1. Date Dimension
CREATE TABLE dim_date (
    date_key DATE PRIMARY KEY,
    full_date_description VARCHAR(50) NOT NULL,
    day_of_month INT NOT NULL,
    day_name VARCHAR(15) NOT NULL,
    day_of_week INT NOT NULL,
    is_weekend TINYINT(1) NOT NULL,
    month_number INT NOT NULL,
    month_name VARCHAR(15) NOT NULL,
    year_month VARCHAR(7) NOT NULL,
    quarter_number INT NOT NULL,
    year_quarter VARCHAR(7) NOT NULL,
    year_number INT NOT NULL
) ENGINE=InnoDB;

-- 2. Customer Dimension (SCD Type 1 with unique customer mapping)
CREATE TABLE dim_customers (
    customer_id VARCHAR(50) PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL,
    zip_code_prefix INT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(5) NOT NULL,
    region VARCHAR(20) NOT NULL,
    INDEX idx_dim_cust_unique (customer_unique_id),
    INDEX idx_dim_cust_state (state)
) ENGINE=InnoDB;

-- 3. Product Dimension (with English translated categories and physical volume)
CREATE TABLE dim_products (
    product_id VARCHAR(50) PRIMARY KEY,
    category_name_pt VARCHAR(100) NOT NULL DEFAULT 'desconhecido',
    category_name_en VARCHAR(100) NOT NULL DEFAULT 'Unknown',
    name_length INT NULL,
    description_length INT NULL,
    photos_qty INT NULL,
    weight_g INT NULL,
    length_cm INT NULL,
    height_cm INT NULL,
    width_cm INT NULL,
    volume_cm3 DECIMAL(12, 2) NULL,
    INDEX idx_dim_prod_cat_en (category_name_en)
) ENGINE=InnoDB;

-- 4. Seller Dimension
CREATE TABLE dim_sellers (
    seller_id VARCHAR(50) PRIMARY KEY,
    zip_code_prefix INT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(5) NOT NULL,
    region VARCHAR(20) NOT NULL,
    INDEX idx_dim_seller_state (state)
) ENGINE=InnoDB;

-- 5. Orders Fact Table (Grain: 1 row per order)
CREATE TABLE fact_orders (
    order_id VARCHAR(50) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    purchase_date DATE NOT NULL,
    purchase_timestamp DATETIME NOT NULL,
    approved_at DATETIME NULL,
    delivered_carrier_date DATETIME NULL,
    delivered_customer_date DATETIME NULL,
    estimated_delivery_date DATETIME NOT NULL,
    delivery_lead_time_days DECIMAL(6, 2) NULL,
    delivery_vs_estimated_days DECIMAL(6, 2) NULL,
    delivery_status VARCHAR(20) NOT NULL, -- 'On-Time', 'Late', 'Undelivered'
    CONSTRAINT fk_fo_customer FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
    CONSTRAINT fk_fo_date FOREIGN KEY (purchase_date) REFERENCES dim_date(date_key),
    INDEX idx_fo_status (order_status),
    INDEX idx_fo_delivery_status (delivery_status)
) ENGINE=InnoDB;

-- 6. Order Items Fact Table (Grain: 1 row per item within an order)
CREATE TABLE fact_order_items (
    order_item_surrogate_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    purchase_date DATE NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    freight_value DECIMAL(10, 2) NOT NULL,
    total_item_value DECIMAL(10, 2) NOT NULL,
    CONSTRAINT fk_foi_order FOREIGN KEY (order_id) REFERENCES fact_orders(order_id),
    CONSTRAINT fk_foi_product FOREIGN KEY (product_id) REFERENCES dim_products(product_id),
    CONSTRAINT fk_foi_seller FOREIGN KEY (seller_id) REFERENCES dim_sellers(seller_id),
    CONSTRAINT fk_foi_date FOREIGN KEY (purchase_date) REFERENCES dim_date(date_key),
    INDEX idx_foi_order (order_id),
    INDEX idx_foi_product (product_id),
    INDEX idx_foi_seller (seller_id)
) ENGINE=InnoDB;

-- 7. Payments Fact Table (Grain: 1 row per payment transaction)
CREATE TABLE fact_payments (
    payment_surrogate_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(20) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(10, 2) NOT NULL,
    CONSTRAINT fk_fp_order FOREIGN KEY (order_id) REFERENCES fact_orders(order_id),
    INDEX idx_fp_order (order_id),
    INDEX idx_fp_type (payment_type)
) ENGINE=InnoDB;

-- 8. Reviews Fact Table (Grain: 1 row per order review)
CREATE TABLE fact_reviews (
    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    review_score INT NOT NULL,
    review_comment_title VARCHAR(255) NULL,
    review_comment_message TEXT NULL,
    review_creation_date DATETIME NOT NULL,
    review_answer_timestamp DATETIME NOT NULL,
    review_response_time_hours DECIMAL(8, 2) NULL,
    PRIMARY KEY (review_id, order_id),
    CONSTRAINT fk_fr_order FOREIGN KEY (order_id) REFERENCES fact_orders(order_id),
    INDEX idx_fr_score (review_score),
    INDEX idx_fr_order (order_id)
) ENGINE=InnoDB;
