"""
E-COMMERCE 360° BUSINESS INTELLIGENCE
Step 5: Cohort Retention Analysis & Heatmap
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams['font.family'] = 'DejaVu Sans'

PROCESSED_DIR = r"data\processed"
REPORT_DIR = r"reports"
DASHBOARD_DIR = r"powerbi\dashboard_screenshots"

os.makedirs(REPORT_DIR, exist_ok=True)
os.makedirs(DASHBOARD_DIR, exist_ok=True)

def run_cohort_analysis():
    print("Loading delivered orders for cohort retention analysis...")
    bi_orders = pd.read_csv(os.path.join(PROCESSED_DIR, "order_summary_bi.csv"))
    delivered = bi_orders[bi_orders['order_status'] == 'delivered'].copy()
    delivered['purchase_date'] = pd.to_datetime(delivered['purchase_date'])
    
    # 1. Determine customer's first purchase date & cohort month
    delivered['order_month'] = delivered['purchase_date'].dt.to_period('M')
    first_purchase = delivered.groupby('customer_unique_id')['order_month'].min().reset_index()
    first_purchase.rename(columns={'order_month': 'cohort_month'}, inplace=True)
    
    # Merge cohort month back
    df = delivered.merge(first_purchase, on='customer_unique_id')
    
    # 2. Calculate cohort index (months elapsed since first purchase)
    def get_month_diff(x):
        return (x['order_month'].dt.year - x['cohort_month'].dt.year) * 12 + (x['order_month'].dt.month - x['cohort_month'].dt.month)
    
    df['cohort_index'] = (df['order_month'].apply(lambda x: x.year * 12 + x.month) - 
                          df['cohort_month'].apply(lambda x: x.year * 12 + x.month))
    
    # 3. Aggregate unique customers per cohort_month and cohort_index
    cohort_data = df.groupby(['cohort_month', 'cohort_index'])['customer_unique_id'].nunique().reset_index()
    
    # Pivot table
    cohort_pivot = cohort_data.pivot(index='cohort_month', columns='cohort_index', values='customer_unique_id')
    
    # Filter 2017 to mid 2018 for meaningful cohort history
    valid_cohorts = [p for p in cohort_pivot.index if '2017-01' <= str(p) <= '2018-03']
    cohort_pivot = cohort_pivot.loc[valid_cohorts]
    
    # Calculate retention percentage relative to month 0
    cohort_size = cohort_pivot.iloc[:, 0]
    retention_matrix = cohort_pivot.divide(cohort_size, axis=0) * 100.0
    
    print("\n--- COHORT RETENTION MATRIX (PERCENTAGE %) ---")
    print(retention_matrix.round(2).fillna("").to_string())
    
    # Save CSV
    retention_matrix.to_csv(os.path.join(PROCESSED_DIR, "cohort_retention_matrix.csv"))
    
    # 4. Generate Cohort Retention Heatmap
    plt.figure(figsize=(14, 8))
    sns.heatmap(
        retention_matrix.iloc[:, 1:13], # Show months 1 to 12
        annot=True,
        fmt='.2f',
        cmap='YlGnBu',
        cbar_kws={'label': 'Retention Rate (%)'},
        linewidths=0.5,
        linecolor='white'
    )
    plt.title("Olist Monthly Customer Cohort Retention Rate (%)", fontsize=15, weight='bold', pad=15)
    plt.xlabel("Cohort Period (Months Since First Purchase)", fontweight='bold', labelpad=10)
    plt.ylabel("Acquisition Cohort (Year-Month)", fontweight='bold', labelpad=10)
    plt.tight_layout()
    
    heatmap_path = os.path.join(REPORT_DIR, "09_cohort_retention_heatmap.png")
    plt.savefig(heatmap_path, dpi=300)
    plt.savefig(os.path.join(DASHBOARD_DIR, "09_cohort_retention_heatmap.png"), dpi=300)
    plt.close()
    print(f"\nCohort Retention Heatmap saved to: {heatmap_path}")

if __name__ == "__main__":
    run_cohort_analysis()
