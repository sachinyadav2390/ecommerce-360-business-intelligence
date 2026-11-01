"""
Create portable local SQLite database with all Star Schema tables and execute analytical queries.
"""

import os
import sqlite3
import pandas as pd

PROCESSED_DIR = r"data\processed"
DB_PATH = r"data\ecommerce_analytics.db"

def build_database():
    print(f"Building SQLite database at: {DB_PATH}")
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
        
    conn = sqlite3.connect(DB_PATH)
    
    tables = [
        "dim_customers",
        "dim_products",
        "dim_sellers",
        "dim_date",
        "fact_orders",
        "fact_order_items",
        "fact_payments",
        "fact_reviews",
        "order_summary_bi",
        "rfm_customer_segments",
        "cohort_retention_matrix"
    ]
    
    for t in tables:
        csv_file = os.path.join(PROCESSED_DIR, f"{t}.csv")
        if os.path.exists(csv_file):
            print(f"Loading {t}...")
            df = pd.read_csv(csv_file)
            df.to_sql(t, conn, if_exists="replace", index=False)
            print(f"  -> {t} loaded: {len(df):,} rows")
            
    print("\nCreating indexes for high-speed analytical joins...")
    cur = conn.cursor()
    cur.execute("CREATE INDEX IF NOT EXISTS idx_fo_order_id ON fact_orders(order_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_fo_cust_id ON fact_orders(customer_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_foi_order_id ON fact_order_items(order_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_foi_prod_id ON fact_order_items(product_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_foi_seller_id ON fact_order_items(seller_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_dc_cust_id ON dim_customers(customer_id);")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_dc_uniq_id ON dim_customers(customer_unique_id);")
    conn.commit()
    
    print("\n" + "=" * 80)
    print("RUNNING CROSS-VALIDATION SQL QUERIES")
    print("=" * 80)
    
    # Query 1: Monthly revenue
    q1 = """
    SELECT 
        d.year_month AS sales_month,
        COUNT(DISTINCT fo.order_id) AS total_orders,
        ROUND(SUM(foi.price), 2) AS realized_revenue,
        ROUND(SUM(foi.price) / COUNT(DISTINCT fo.order_id), 2) AS aov
    FROM fact_orders fo
    JOIN dim_date d ON fo.purchase_date = d.date_key
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY d.year_month
    ORDER BY d.year_month DESC
    LIMIT 5;
    """
    print("\n--- Query 1: Recent Monthly Revenue & AOV ---")
    df_q1 = pd.read_sql_query(q1, conn)
    print(df_q1.to_string(index=False))
    
    # Query 2: Top 5 Categories
    q2 = """
    SELECT 
        p.category_name_en,
        COUNT(DISTINCT foi.order_id) AS total_orders,
        ROUND(SUM(foi.price), 2) AS total_revenue
    FROM fact_order_items foi
    JOIN dim_products p ON foi.product_id = p.product_id
    JOIN fact_orders fo ON foi.order_id = fo.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY p.category_name_en
    ORDER BY total_revenue DESC
    LIMIT 5;
    """
    print("\n--- Query 2: Top 5 Revenue-Generating Categories ---")
    df_q2 = pd.read_sql_query(q2, conn)
    print(df_q2.to_string(index=False))
    
    # Query 3: Repeat Customer Rate
    q3 = """
    WITH customer_orders AS (
        SELECT 
            c.customer_unique_id,
            COUNT(DISTINCT fo.order_id) AS order_count
        FROM fact_orders fo
        JOIN dim_customers c ON fo.customer_id = c.customer_id
        WHERE fo.order_status = 'delivered'
        GROUP BY c.customer_unique_id
    )
    SELECT 
        COUNT(*) AS total_unique_buyers,
        SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_buyers,
        ROUND(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_buyer_pct
    FROM customer_orders;
    """
    print("\n--- Query 3: Customer Retention & Repeat Purchase Rate ---")
    df_q3 = pd.read_sql_query(q3, conn)
    print(df_q3.to_string(index=False))
    
    # Query 4: Delivery Lead Time vs Review Score
    q4 = """
    SELECT 
        CASE 
            WHEN delivery_lead_time_days <= 3 THEN '0-3 Days'
            WHEN delivery_lead_time_days <= 7 THEN '4-7 Days'
            WHEN delivery_lead_time_days <= 14 THEN '8-14 Days'
            WHEN delivery_lead_time_days <= 21 THEN '15-21 Days'
            WHEN delivery_lead_time_days <= 30 THEN '22-30 Days'
            ELSE '> 30 Days'
        END AS lead_time_cohort,
        COUNT(*) AS delivered_orders,
        ROUND(AVG(avg_review_score), 2) AS avg_csat_rating
    FROM order_summary_bi
    WHERE order_status = 'delivered' AND delivery_lead_time_days IS NOT NULL AND avg_review_score IS NOT NULL
    GROUP BY lead_time_cohort
    ORDER BY MIN(delivery_lead_time_days);
    """
    print("\n--- Query 4: Logistics SLA Impact on CSAT Rating ---")
    df_q4 = pd.read_sql_query(q4, conn)
    print(df_q4.to_string(index=False))
    
    conn.close()
    print("\nDatabase built successfully!")

if __name__ == '__main__':
    build_database()
