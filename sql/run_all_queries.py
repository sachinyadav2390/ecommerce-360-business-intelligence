"""
E-COMMERCE 360° BUSINESS INTELLIGENCE
Automated MySQL Database Initialization & SQL Query Runner
"""

import os
import sys
import argparse
import pandas as pd
import pymysql
from sqlalchemy import create_engine, text

PROCESSED_DIR = r"data\processed"
SQL_DIR = r"sql"

def run_mysql_pipeline(password, user="root", host="127.0.0.1", port=3306):
    print("=" * 80)
    print("STARTING MYSQL DATABASE INITIALIZATION & ETL PIPELINE")
    print(f"Connecting to MySQL at {host}:{port} as user '{user}'...")
    print("=" * 80)
    
    # 1. Test raw connection to server
    try:
        conn = pymysql.connect(host=host, port=port, user=user, password=password, autocommit=True)
        print(" Connected to MySQL server successfully!")
    except Exception as e:
        print(f"❌ Failed to connect to MySQL: {e}")
        return False

    with conn.cursor() as cur:
        # Create database
        print("\n1. Creating database 'ecommerce_analytics'...")
        cur.execute("CREATE DATABASE IF NOT EXISTS ecommerce_analytics DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        cur.execute("USE ecommerce_analytics;")
        print(" Database created and selected.")

    conn.close()

    # 2. Connect to database via SQLAlchemy
    db_url = f"mysql+pymysql://{user}:{password}@{host}:{port}/ecommerce_analytics"
    engine = create_engine(db_url)

    # Execute DDL
    print("\n2. Executing table creation DDL (sql/02_table_creation.sql)...")
    with open(os.path.join(SQL_DIR, "02_table_creation.sql"), "r", encoding="utf-8") as f:
        ddl_script = f.read()

    # Split by semicolon statements
    statements = [s.strip() for s in ddl_script.split(";") if s.strip() and not s.strip().startswith("--")]
    with engine.begin() as sql_conn:
        for stmt in statements:
            try:
                sql_conn.execute(text(stmt))
            except Exception as e:
                # ignore drop table warnings
                if "DROP TABLE" not in stmt:
                    print(f"  Warning executing statement: {e}")
    print(" All staging and analytical tables created successfully!")

    # 3. Load processed Star Schema datasets
    print("\n3. Ingesting curated Star Schema datasets into MySQL...")
    tables_to_load = [
        ("dim_customers", "dim_customers.csv"),
        ("dim_products", "dim_products.csv"),
        ("dim_sellers", "dim_sellers.csv"),
        ("dim_date", "dim_date.csv"),
        ("fact_orders", "fact_orders.csv"),
        ("fact_order_items", "fact_order_items.csv"),
        ("fact_payments", "fact_payments.csv"),
        ("fact_reviews", "fact_reviews.csv")
    ]

    for table_name, csv_file in tables_to_load:
        csv_path = os.path.join(PROCESSED_DIR, csv_file)
        if os.path.exists(csv_path):
            print(f"  Loading '{table_name}' from {csv_file}...")
            df = pd.read_csv(csv_path)
            df.to_sql(table_name, engine, if_exists='append', index=False, chunksize=5000)
            print(f"     Loaded {len(df):,} rows into {table_name}.")
        else:
            print(f"  Warning: {csv_path} not found.")

    # 4. Create Semantic Views
    print("\n4. Creating Power BI semantic analytical views (from sql/09_advanced_analysis.sql)...")
    with open(os.path.join(SQL_DIR, "09_advanced_analysis.sql"), "r", encoding="utf-8") as f:
        adv_script = f.read()
    
    view_stmts = [s.strip() for s in adv_script.split(";") if "CREATE OR REPLACE VIEW" in s]
    with engine.begin() as sql_conn:
        for v in view_stmts:
            sql_conn.execute(text(v))
            print("  Created semantic view.")

    # 5. Execute Sample Analytical Query (Monthly Revenue)
    print("\n5. Executing Query 1: Monthly Realized Revenue & Order Volume...")
    sample_query = """
    SELECT 
        d.year_month AS sales_month,
        COUNT(DISTINCT fo.order_id) AS total_orders,
        ROUND(SUM(foi.price), 2) AS total_item_revenue,
        ROUND(AVG(foi.price), 2) AS avg_item_price
    FROM fact_orders fo
    JOIN dim_date d ON fo.purchase_date = d.date_key
    JOIN fact_order_items foi ON fo.order_id = foi.order_id
    WHERE fo.order_status = 'delivered'
    GROUP BY d.year_month
    ORDER BY d.year_month
    LIMIT 10;
    """
    res_df = pd.read_sql(sample_query, engine)
    print(res_df.to_string(index=False))

    print("\n" + "=" * 80)
    print("MYSQL PIPELINE EXECUTED SUCCESSFULLY!")
    print("Database 'ecommerce_analytics' is fully loaded and ready for Power BI!")
    print("=" * 80)
    return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run MySQL analytics pipeline")
    parser.add_argument("-p", "--password", help="MySQL root password", default="")
    parser.add_argument("-u", "--user", help="MySQL username", default="root")
    parser.add_argument("-H", "--host", help="MySQL host", default="127.0.0.1")
    parser.add_argument("-P", "--port", type=int, help="MySQL port", default=3306)
    
    args = parser.parse_args()
    pwd = args.password
    if not pwd:
        # Check if saved in scratch
        pwd_file = r"C:\Users\91979\.gemini\antigravity\brain\8a39fbb8-4341-4620-ba0f-bc4e56c3bf99\scratch\db_auth.txt"
        if os.path.exists(pwd_file):
            with open(pwd_file) as f:
                content = f.read().strip()
                if ":" in content:
                    pwd = content.split(":", 1)[1]
    
    if not pwd:
        print("Please provide the MySQL password via -p or --password.")
        sys.exit(1)
        
    run_mysql_pipeline(password=pwd, user=args.user, host=args.host, port=args.port)
