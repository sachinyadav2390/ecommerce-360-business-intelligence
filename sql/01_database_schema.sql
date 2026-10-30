-- =============================================================================
-- E-COMMERCE 360° BUSINESS INTELLIGENCE PLATFORM
-- Script 01: Database Architecture & Schema Initialization
-- DBMS: MySQL 8.0+
-- Database: ecommerce_analytics
-- =============================================================================

-- Description:
-- Initializes the relational database for the end-to-end e-commerce analytics project.
-- Sets optimal character encoding (utf8mb4) and collation for Brazilian Portuguese text.
-- Establishes two logical layers:
--   1. STAGING LAYER (raw_*) for direct ELT ingestion from Olist CSVs
--   2. ANALYTICAL LAYER (dim_* & fact_*) organized as an optimized Star Schema

DROP DATABASE IF EXISTS ecommerce_analytics;
CREATE DATABASE ecommerce_analytics
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE ecommerce_analytics;

-- Display verification
SELECT 
    DATABASE() AS current_database,
    @@character_set_database AS default_charset,
    @@collation_database AS default_collation,
    NOW() AS initialized_at;
