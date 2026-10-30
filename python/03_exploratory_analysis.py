"""
E-COMMERCE 360° BUSINESS INTELLIGENCE
Step 3: Exploratory Data Analysis (EDA) & High-Resolution Visualizations
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['font.size'] = 11

PROCESSED_DIR = r"data\processed"
REPORT_IMG_DIR = r"reports"
DASHBOARD_IMG_DIR = r"powerbi\dashboard_screenshots"

os.makedirs(REPORT_IMG_DIR, exist_ok=True)
os.makedirs(DASHBOARD_IMG_DIR, exist_ok=True)

def run_eda():
    print("Loading processed data for EDA...")
    bi_orders = pd.read_csv(os.path.join(PROCESSED_DIR, "order_summary_bi.csv"))
    order_items = pd.read_csv(os.path.join(PROCESSED_DIR, "fact_order_items.csv"))
    products = pd.read_csv(os.path.join(PROCESSED_DIR, "dim_products.csv"))
    
    # Filter delivered orders
    delivered = bi_orders[bi_orders['order_status'] == 'delivered'].copy()
    
    # 1. Monthly Revenue & Order Count Trend
    monthly = delivered.groupby('year_month').agg(
        revenue=('total_item_revenue', 'sum'),
        orders=('order_id', 'count')
    ).reset_index()
    monthly = monthly[(monthly['year_month'] >= '2017-01') & (monthly['year_month'] <= '2018-08')]
    
    fig, ax1 = plt.subplots(figsize=(12, 6))
    color = '#1f77b4'
    ax1.set_title("Monthly Realized Revenue and Order Volume Trend (2017 - 2018)", fontsize=14, weight='bold', pad=15)
    ax1.plot(monthly['year_month'], monthly['revenue'] / 1000.0, marker='o', color=color, linewidth=2.5, label='Revenue (k BRL)')
    ax1.set_xlabel("Purchase Month", fontweight='bold', labelpad=10)
    ax1.set_ylabel("Revenue (Thousands BRL)", color=color, fontweight='bold')
    ax1.tick_params(axis='y', labelcolor=color)
    ax1.tick_params(axis='x', rotation=45)
    
    ax2 = ax1.twinx()
    color2 = '#ff7f0e'
    ax2.bar(monthly['year_month'], monthly['orders'], alpha=0.3, color=color2, width=0.5, label='Total Orders')
    ax2.set_ylabel("Order Count", color=color2, fontweight='bold')
    ax2.tick_params(axis='y', labelcolor=color2)
    ax2.grid(False)
    
    fig.tight_layout()
    chart1_path = os.path.join(REPORT_IMG_DIR, "01_monthly_revenue_trend.png")
    fig.savefig(chart1_path, dpi=300)
    fig.savefig(os.path.join(DASHBOARD_IMG_DIR, "01_monthly_revenue_trend.png"), dpi=300)
    plt.close()
    print(f"Saved: {chart1_path}")

    # 2. Top 10 Product Categories by Revenue
    items_prod = order_items.merge(products[['product_id', 'category_name_en']], on='product_id', how='left')
    cat_sales = items_prod.groupby('category_name_en')['price'].sum().reset_index()
    cat_sales = cat_sales.sort_values('price', ascending=False).head(10)
    
    plt.figure(figsize=(10, 6))
    ax = sns.barplot(x='price', y='category_name_en', data=cat_sales, palette='crest')
    plt.title("Top 10 Product Categories by Revenue (BRL)", fontsize=14, weight='bold', pad=15)
    plt.xlabel("Total Revenue (BRL)", fontweight='bold')
    plt.ylabel("Product Category", fontweight='bold')
    
    for p in ax.patches:
        width = p.get_width()
        ax.annotate(f"R$ {width/1e6:.2f}M", (width, p.get_y() + p.get_height() / 2.),
                    ha='left', va='center', xytext=(5, 0), textcoords='offset points', fontsize=9, weight='bold')
    
    plt.tight_layout()
    chart2_path = os.path.join(REPORT_IMG_DIR, "02_top10_categories_revenue.png")
    plt.savefig(chart2_path, dpi=300)
    plt.savefig(os.path.join(DASHBOARD_IMG_DIR, "02_top10_categories_revenue.png"), dpi=300)
    plt.close()
    print(f"Saved: {chart2_path}")

    # 3. Macro-Region Sales Contribution (Pie / Donut)
    reg_sales = delivered.groupby('region')['total_item_revenue'].sum().reset_index()
    reg_sales = reg_sales.sort_values('total_item_revenue', ascending=False)
    
    plt.figure(figsize=(8, 8))
    colors = ['#2ca02c', '#1f77b4', '#ff7f0e', '#d62728', '#9467bd']
    plt.pie(reg_sales['total_item_revenue'], labels=reg_sales['region'], autopct='%1.1f%%',
            startangle=140, colors=colors, explode=[0.05, 0, 0, 0, 0],
            wedgeprops={'edgecolor': 'white', 'linewidth': 2},
            textprops={'fontsize': 11, 'weight': 'bold'})
    plt.title("Revenue Contribution by Brazilian Macro-Region", fontsize=14, weight='bold', pad=20)
    plt.tight_layout()
    chart3_path = os.path.join(REPORT_IMG_DIR, "03_regional_sales_distribution.png")
    plt.savefig(chart3_path, dpi=300)
    plt.savefig(os.path.join(DASHBOARD_IMG_DIR, "03_regional_sales_distribution.png"), dpi=300)
    plt.close()
    print(f"Saved: {chart3_path}")

    # 4. Delivery Lead Time vs Review Score Correlation
    lead_reviews = delivered.dropna(subset=['delivery_lead_time_days', 'avg_review_score']).copy()
    lead_reviews['lead_tier'] = pd.cut(
        lead_reviews['delivery_lead_time_days'],
        bins=[-np.inf, 3, 7, 14, 21, 30, np.inf],
        labels=['<= 3 days', '4-7 days', '8-14 days', '15-21 days', '22-30 days', '> 30 days']
    )
    lead_summary = lead_reviews.groupby('lead_tier', observed=False).agg(
        avg_rating=('avg_review_score', 'mean'),
        orders=('order_id', 'count')
    ).reset_index()
    
    fig, ax1 = plt.subplots(figsize=(10, 6))
    sns.barplot(x='lead_tier', y='orders', data=lead_summary, ax=ax1, color='#aec7e8', alpha=0.7)
    ax1.set_ylabel("Order Count", fontweight='bold', color='#1f77b4')
    ax1.set_xlabel("Delivery Lead Time Tier", fontweight='bold')
    
    ax2 = ax1.twinx()
    ax2.plot(lead_summary['lead_tier'], lead_summary['avg_rating'], color='#d62728', marker='s', linewidth=3, label='Avg Review Rating')
    ax2.set_ylabel("Average Review Rating (1-5 Stars)", fontweight='bold', color='#d62728')
    ax2.set_ylim(1.0, 5.0)
    ax2.grid(False)
    
    for i, txt in enumerate(lead_summary['avg_rating']):
        ax2.annotate(f"{txt:.2f} ★", (i, txt + 0.15), ha='center', fontweight='bold', color='#d62728')
        
    plt.title("Impact of Delivery Transit Duration on Customer Satisfaction Rating", fontsize=14, weight='bold', pad=15)
    fig.tight_layout()
    chart4_path = os.path.join(REPORT_IMG_DIR, "04_delivery_time_vs_rating.png")
    fig.savefig(chart4_path, dpi=300)
    fig.savefig(os.path.join(DASHBOARD_IMG_DIR, "04_delivery_time_vs_rating.png"), dpi=300)
    plt.close()
    print(f"Saved: {chart4_path}")

    # 5. Payment Method & Installments Distribution
    pay_summary = delivered.groupby('primary_payment_type').agg(
        revenue=('total_item_revenue', 'sum'),
        orders=('order_id', 'count')
    ).reset_index().sort_values('revenue', ascending=False)
    
    plt.figure(figsize=(9, 5))
    ax = sns.barplot(x='primary_payment_type', y='revenue', data=pay_summary, palette='mako')
    plt.title("Revenue by Primary Payment Instrument", fontsize=14, weight='bold', pad=15)
    plt.xlabel("Payment Type", fontweight='bold')
    plt.ylabel("Revenue (BRL)", fontweight='bold')
    for p in ax.patches:
        ax.annotate(f"R$ {p.get_height()/1e6:.2f}M", (p.get_x() + p.get_width() / 2., p.get_height()),
                    ha='center', va='bottom', xytext=(0, 5), textcoords='offset points', weight='bold')
    plt.tight_layout()
    chart5_path = os.path.join(REPORT_IMG_DIR, "05_payment_instruments.png")
    plt.savefig(chart5_path, dpi=300)
    plt.savefig(os.path.join(DASHBOARD_IMG_DIR, "05_payment_instruments.png"), dpi=300)
    plt.close()
    print(f"Saved: {chart5_path}")

    print("\nAll EDA charts generated and saved successfully!")

if __name__ == "__main__":
    run_eda()
