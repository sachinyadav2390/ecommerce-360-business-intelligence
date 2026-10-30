"""
E-COMMERCE 360° BUSINESS INTELLIGENCE
Step 2: Data Cleaning & Star Schema Transformation Pipeline
"""

import os
import pandas as pd
import numpy as np

RAW_DIR = r"data\raw"
PROCESSED_DIR = r"data\processed"

os.makedirs(PROCESSED_DIR, exist_ok=True)

STATE_REGION_MAP = {
    'SP': 'Southeast', 'RJ': 'Southeast', 'MG': 'Southeast', 'ES': 'Southeast',
    'PR': 'South', 'SC': 'South', 'RS': 'South',
    'BA': 'Northeast', 'PE': 'Northeast', 'CE': 'Northeast', 'MA': 'Northeast',
    'PB': 'Northeast', 'RN': 'Northeast', 'AL': 'Northeast', 'SE': 'Northeast', 'PI': 'Northeast',
    'MT': 'Central-West', 'MS': 'Central-West', 'GO': 'Central-West', 'DF': 'Central-West',
    'AM': 'North', 'PA': 'North', 'RO': 'North', 'TO': 'North', 'AC': 'North', 'AP': 'North', 'RR': 'North'
}

def clean_data():
    print("Loading raw datasets...")
    df_customers = pd.read_csv(os.path.join(RAW_DIR, "olist_customers_dataset.csv"))
    df_orders = pd.read_csv(os.path.join(RAW_DIR, "olist_orders_dataset.csv"))
    df_order_items = pd.read_csv(os.path.join(RAW_DIR, "olist_order_items_dataset.csv"))
    df_payments = pd.read_csv(os.path.join(RAW_DIR, "olist_order_payments_dataset.csv"))
    df_reviews = pd.read_csv(os.path.join(RAW_DIR, "olist_order_reviews_dataset.csv"))
    df_products = pd.read_csv(os.path.join(RAW_DIR, "olist_products_dataset.csv"))
    df_sellers = pd.read_csv(os.path.join(RAW_DIR, "olist_sellers_dataset.csv"))
    df_trans = pd.read_csv(os.path.join(RAW_DIR, "product_category_name_translation.csv"))
    
    print("\n1. Transforming dim_customers...")
    df_customers['customer_city'] = df_customers['customer_city'].str.strip().str.title()
    df_customers['customer_state'] = df_customers['customer_state'].str.strip().str.upper()
    df_customers['region'] = df_customers['customer_state'].map(STATE_REGION_MAP).fillna('Other')
    dim_customers = df_customers.rename(columns={'customer_zip_code_prefix': 'zip_code_prefix', 'customer_city': 'city', 'customer_state': 'state'})
    dim_customers.to_csv(os.path.join(PROCESSED_DIR, "dim_customers.csv"), index=False)
    print(f"   dim_customers saved: {dim_customers.shape}")

    print("\n2. Transforming dim_products...")
    df_products = df_products.merge(df_trans, on='product_category_name', how='left')
    df_products['category_name_en'] = df_products['product_category_name_english'].fillna(
        df_products['product_category_name'].str.replace('_', ' ').str.title()
    ).fillna('Unknown')
    df_products['category_name_pt'] = df_products['product_category_name'].fillna('desconhecido')
    df_products['volume_cm3'] = (df_products['product_length_cm'].fillna(0) * 
                                 df_products['product_height_cm'].fillna(0) * 
                                 df_products['product_width_cm'].fillna(0)).round(2)
    dim_products = df_products[['product_id', 'category_name_pt', 'category_name_en', 
                                'product_name_lenght', 'product_description_lenght', 'product_photos_qty',
                                'product_weight_g', 'product_length_cm', 'product_height_cm', 'product_width_cm', 'volume_cm3']]
    dim_products.to_csv(os.path.join(PROCESSED_DIR, "dim_products.csv"), index=False)
    print(f"   dim_products saved: {dim_products.shape}")

    print("\n3. Transforming dim_sellers...")
    df_sellers['seller_city'] = df_sellers['seller_city'].str.strip().str.title()
    df_sellers['seller_state'] = df_sellers['seller_state'].str.strip().str.upper()
    df_sellers['region'] = df_sellers['seller_state'].map(STATE_REGION_MAP).fillna('Other')
    dim_sellers = df_sellers.rename(columns={'seller_zip_code_prefix': 'zip_code_prefix', 'seller_city': 'city', 'seller_state': 'state'})
    dim_sellers.to_csv(os.path.join(PROCESSED_DIR, "dim_sellers.csv"), index=False)
    print(f"   dim_sellers saved: {dim_sellers.shape}")

    print("\n4. Generating dim_date...")
    date_range = pd.date_range(start='2016-01-01', end='2018-12-31', freq='D')
    dim_date = pd.DataFrame({'date_key': date_range})
    dim_date['full_date_description'] = dim_date['date_key'].dt.strftime('%A, %B %d, %Y')
    dim_date['day_of_month'] = dim_date['date_key'].dt.day
    dim_date['day_name'] = dim_date['date_key'].dt.day_name()
    dim_date['day_of_week'] = dim_date['date_key'].dt.dayofweek + 1
    dim_date['is_weekend'] = dim_date['day_of_week'].isin([6, 7]).astype(int)
    dim_date['month_number'] = dim_date['date_key'].dt.month
    dim_date['month_name'] = dim_date['date_key'].dt.month_name()
    dim_date['year_month'] = dim_date['date_key'].dt.strftime('%Y-%m')
    dim_date['quarter_number'] = dim_date['date_key'].dt.quarter
    dim_date['year_quarter'] = dim_date['date_key'].dt.year.astype(str) + '-Q' + dim_date['quarter_number'].astype(str)
    dim_date['year_number'] = dim_date['date_key'].dt.year
    dim_date.to_csv(os.path.join(PROCESSED_DIR, "dim_date.csv"), index=False)
    print(f"   dim_date saved: {dim_date.shape}")

    print("\n5. Transforming fact_orders...")
    for dt_col in ['order_purchase_timestamp', 'order_approved_at', 'order_delivered_carrier_date', 
                   'order_delivered_customer_date', 'order_estimated_delivery_date']:
        df_orders[dt_col] = pd.to_datetime(df_orders[dt_col], errors='coerce')
    
    df_orders['purchase_date'] = df_orders['order_purchase_timestamp'].dt.date
    df_orders['delivery_lead_time_days'] = ((df_orders['order_delivered_customer_date'] - df_orders['order_purchase_timestamp']).dt.total_seconds() / 86400.0).round(2)
    df_orders['delivery_vs_estimated_days'] = ((df_orders['order_delivered_customer_date'] - df_orders['order_estimated_delivery_date']).dt.total_seconds() / 86400.0).round(2)
    
    conditions = [
        df_orders['order_delivered_customer_date'].isnull(),
        df_orders['order_delivered_customer_date'] > df_orders['order_estimated_delivery_date']
    ]
    choices = ['Undelivered', 'Late']
    df_orders['delivery_status'] = np.select(conditions, choices, default='On-Time')
    
    fact_orders = df_orders[['order_id', 'customer_id', 'order_status', 'purchase_date', 
                             'order_purchase_timestamp', 'order_approved_at', 'order_delivered_carrier_date',
                             'order_delivered_customer_date', 'order_estimated_delivery_date',
                             'delivery_lead_time_days', 'delivery_vs_estimated_days', 'delivery_status']]
    fact_orders.to_csv(os.path.join(PROCESSED_DIR, "fact_orders.csv"), index=False)
    print(f"   fact_orders saved: {fact_orders.shape}")

    print("\n6. Transforming fact_order_items...")
    df_order_items['shipping_limit_date'] = pd.to_datetime(df_order_items['shipping_limit_date'], errors='coerce')
    df_order_items = df_order_items.merge(fact_orders[['order_id', 'purchase_date']], on='order_id', how='inner')
    df_order_items['total_item_value'] = (df_order_items['price'] + df_order_items['freight_value']).round(2)
    fact_order_items = df_order_items[['order_id', 'order_item_id', 'product_id', 'seller_id', 
                                       'purchase_date', 'shipping_limit_date', 'price', 'freight_value', 'total_item_value']]
    fact_order_items.to_csv(os.path.join(PROCESSED_DIR, "fact_order_items.csv"), index=False)
    print(f"   fact_order_items saved: {fact_order_items.shape}")

    print("\n7. Transforming fact_payments...")
    fact_payments = df_payments[['order_id', 'payment_sequential', 'payment_type', 'payment_installments', 'payment_value']]
    fact_payments.to_csv(os.path.join(PROCESSED_DIR, "fact_payments.csv"), index=False)
    print(f"   fact_payments saved: {fact_payments.shape}")

    print("\n8. Transforming fact_reviews...")
    df_reviews['review_creation_date'] = pd.to_datetime(df_reviews['review_creation_date'], errors='coerce')
    df_reviews['review_answer_timestamp'] = pd.to_datetime(df_reviews['review_answer_timestamp'], errors='coerce')
    df_reviews['review_response_time_hours'] = ((df_reviews['review_answer_timestamp'] - df_reviews['review_creation_date']).dt.total_seconds() / 3600.0).round(2)
    fact_reviews = df_reviews[['review_id', 'order_id', 'review_score', 'review_creation_date', 
                               'review_answer_timestamp', 'review_response_time_hours', 
                               'review_comment_title', 'review_comment_message']]
    fact_reviews.to_csv(os.path.join(PROCESSED_DIR, "fact_reviews.csv"), index=False)
    print(f"   fact_reviews saved: {fact_reviews.shape}")

    print("\n9. Generating curated Power BI semantic order-level view (view_powerbi_orders.csv)...")
    oi_agg = fact_order_items.groupby('order_id').agg(
        total_item_revenue=('price', 'sum'),
        total_freight_value=('freight_value', 'sum'),
        total_order_value=('total_item_value', 'sum'),
        total_items=('order_item_id', 'count')
    ).reset_index()

    pay_agg = fact_payments.groupby('order_id').agg(
        total_payment_value=('payment_value', 'sum'),
        primary_payment_type=('payment_type', lambda x: x.mode()[0] if not x.empty else 'unknown'),
        avg_installments=('payment_installments', 'mean')
    ).reset_index()

    rev_agg = fact_reviews.groupby('order_id').agg(
        avg_review_score=('review_score', 'mean'),
        has_review=('review_score', lambda x: 1 if len(x) > 0 else 0)
    ).reset_index()

    bi_orders = fact_orders.merge(dim_customers[['customer_id', 'customer_unique_id', 'city', 'state', 'region']], on='customer_id', how='left')
    bi_orders = bi_orders.merge(oi_agg, on='order_id', how='left')
    bi_orders = bi_orders.merge(pay_agg, on='order_id', how='left')
    bi_orders = bi_orders.merge(rev_agg, on='order_id', how='left')
    bi_orders['year_month'] = pd.to_datetime(bi_orders['purchase_date']).dt.strftime('%Y-%m')
    bi_orders['year_quarter'] = pd.to_datetime(bi_orders['purchase_date']).dt.year.astype(str) + '-Q' + pd.to_datetime(bi_orders['purchase_date']).dt.quarter.astype(str)
    
    bi_orders.to_csv(os.path.join(PROCESSED_DIR, "order_summary_bi.csv"), index=False)
    print(f"   order_summary_bi saved: {bi_orders.shape}")
    print("\nAll processed datasets successfully built in 'data/processed'!")

if __name__ == "__main__":
    clean_data()
