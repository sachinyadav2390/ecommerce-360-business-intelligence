"""
E-COMMERCE 360° BUSINESS INTELLIGENCE
Step 4: Customer Segmentation (RFM Analysis & K-Means Clustering)
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams['font.family'] = 'DejaVu Sans'

PROCESSED_DIR = r"data\processed"
REPORT_DIR = r"reports"
DASHBOARD_DIR = r"powerbi\dashboard_screenshots"

os.makedirs(REPORT_DIR, exist_ok=True)
os.makedirs(DASHBOARD_DIR, exist_ok=True)

def run_customer_segmentation():
    print("Loading delivered order data for RFM segmentation...")
    bi_orders = pd.read_csv(os.path.join(PROCESSED_DIR, "order_summary_bi.csv"))
    delivered = bi_orders[bi_orders['order_status'] == 'delivered'].copy()
    delivered['purchase_date'] = pd.to_datetime(delivered['purchase_date'])
    
    # Reference anchor date (day after latest purchase date)
    ref_date = delivered['purchase_date'].max() + pd.Timedelta(days=1)
    print(f"Reference Date: {ref_date.strftime('%Y-%m-%d')}")
    
    # 1. Calculate RFM metrics per customer_unique_id
    rfm = delivered.groupby('customer_unique_id').agg(
        recency=('purchase_date', lambda x: (ref_date - x.max()).days),
        frequency=('order_id', 'nunique'),
        monetary=('total_item_revenue', 'sum'),
        customer_state=('state', 'first'),
        customer_region=('region', 'first')
    ).reset_index()
    
    print(f"Total Unique Customers analyzed: {len(rfm):,}")
    
    # 2. Assign RFM Quartile / Quintile Scores
    rfm['r_score'] = pd.qcut(rfm['recency'], q=5, labels=[5, 4, 3, 2, 1]).astype(int)
    # Frequency is heavily concentrated at 1 purchase (~97%)
    rfm['f_score'] = np.where(rfm['frequency'] > 1, 5, 1)
    rfm['m_score'] = pd.qcut(rfm['monetary'], q=5, labels=[1, 2, 3, 4, 5]).astype(int)
    
    # Business segment categorization
    def assign_segment(row):
        r, f, m = row['r_score'], row['f_score'], row['m_score']
        if r >= 4 and f == 5 and m >= 4:
            return 'Champions'
        elif r >= 3 and f == 5:
            return 'Loyal Customers'
        elif r >= 4 and f == 1 and m >= 3:
            return 'Potential Loyalists'
        elif r >= 3 and f == 1:
            return 'Recent Customers'
        elif r <= 2 and f == 5:
            return 'At Risk'
        elif r <= 2 and m >= 4:
            return "Can't Lose Them"
        else:
            return 'Hibernating / Inactive'

    rfm['customer_segment'] = rfm.apply(assign_segment, axis=1)
    
    # Segment profile summary
    seg_summary = rfm.groupby('customer_segment').agg(
        customers=('customer_unique_id', 'count'),
        avg_recency=('recency', 'mean'),
        avg_frequency=('frequency', 'mean'),
        avg_monetary=('monetary', 'mean'),
        total_revenue=('monetary', 'sum')
    ).reset_index()
    seg_summary['pct_customers'] = (100.0 * seg_summary['customers'] / len(rfm)).round(2)
    seg_summary['pct_revenue'] = (100.0 * seg_summary['total_revenue'] / rfm['monetary'].sum()).round(2)
    seg_summary = seg_summary.sort_values('total_revenue', ascending=False)
    
    print("\n--- RFM SEGMENTS EXECUTIVE SUMMARY ---")
    print(seg_summary.to_string(index=False))
    
    # Visualize RFM Segment Distribution
    plt.figure(figsize=(10, 6))
    ax = sns.barplot(x='total_revenue', y='customer_segment', data=seg_summary, palette='viridis')
    plt.title("Total Realized Revenue by RFM Customer Segment", fontsize=14, weight='bold', pad=15)
    plt.xlabel("Total Revenue (BRL)", fontweight='bold')
    plt.ylabel("Customer Segment", fontweight='bold')
    for p in ax.patches:
        w = p.get_width()
        ax.annotate(f"R$ {w/1e6:.2f}M ({w/rfm['monetary'].sum()*100:.1f}%)", (w, p.get_y() + p.get_height() / 2.),
                    ha='left', va='center', xytext=(5, 0), textcoords='offset points', weight='bold')
    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, "06_rfm_segments_distribution.png"), dpi=300)
    plt.savefig(os.path.join(DASHBOARD_DIR, "06_rfm_segments_distribution.png"), dpi=300)
    plt.close()

    # 3. K-Means Machine Learning Clustering
    print("\nPreparing features for K-Means Clustering...")
    rfm_ml = rfm[['recency', 'frequency', 'monetary']].copy()
    # Log transformation to handle heavy skewness
    rfm_log = np.log1p(rfm_ml)
    
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(rfm_log)
    
    # Determine optimal k via Elbow Curve and Silhouette Analysis
    k_range = range(2, 8)
    inertias = []
    silhouette_scores = []
    
    # Use representative subsample for fast silhouette computation
    sample_indices = np.random.RandomState(42).choice(X_scaled.shape[0], size=10000, replace=False)
    X_sample = X_scaled[sample_indices]
    
    for k in k_range:
        kmeans = KMeans(n_clusters=k, random_state=42, n_init=10)
        kmeans.fit(X_scaled)
        inertias.append(kmeans.inertia_)
        sil_score = silhouette_score(X_sample, kmeans.predict(X_sample))
        silhouette_scores.append(sil_score)
        print(f"  k={k} -> Inertia: {kmeans.inertia_:.1f}, Silhouette Score: {sil_score:.4f}")
    
    # Plot Elbow & Silhouette
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
    ax1.plot(k_range, inertias, marker='o', color='#1f77b4', linewidth=2)
    ax1.set_title("Elbow Method for Optimal k", fontsize=13, weight='bold')
    ax1.set_xlabel("Number of Clusters (k)", fontweight='bold')
    ax1.set_ylabel("Inertia (Within-Cluster Sum of Squares)", fontweight='bold')
    
    ax2.plot(k_range, silhouette_scores, marker='s', color='#2ca02c', linewidth=2)
    ax2.set_title("Silhouette Score Evaluation across k", fontsize=13, weight='bold')
    ax2.set_xlabel("Number of Clusters (k)", fontweight='bold')
    ax2.set_ylabel("Silhouette Coefficient", fontweight='bold')
    
    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, "07_kmeans_elbow_silhouette.png"), dpi=300)
    plt.savefig(os.path.join(DASHBOARD_DIR, "07_kmeans_elbow_silhouette.png"), dpi=300)
    plt.close()
    
    # Fit final model with k=4
    optimal_k = 4
    final_kmeans = KMeans(n_clusters=optimal_k, random_state=42, n_init=10)
    rfm['kmeans_cluster'] = final_kmeans.fit_predict(X_scaled)
    
    # Map cluster numbers to meaningful business personas
    cluster_profiles = rfm.groupby('kmeans_cluster').agg(
        size=('customer_unique_id', 'count'),
        avg_recency=('recency', 'mean'),
        avg_frequency=('frequency', 'mean'),
        avg_monetary=('monetary', 'mean')
    ).reset_index()
    
    print("\n--- K-MEANS CLUSTER PROFILES (k=4) ---")
    print(cluster_profiles.to_string(index=False))
    
    # Visualize 2D Scatter: Recency vs Monetary
    plt.figure(figsize=(10, 6))
    sns.scatterplot(
        x='recency', y='monetary', hue='kmeans_cluster',
        data=rfm.sample(min(10000, len(rfm)), random_state=42),
        palette='Set1', alpha=0.6, s=25
    )
    plt.yscale('log')
    plt.title("K-Means Customer Clusters (Sample 10,000 Customers)", fontsize=14, weight='bold', pad=15)
    plt.xlabel("Recency (Days since last purchase)", fontweight='bold')
    plt.ylabel("Monetary Value in BRL (Log Scale)", fontweight='bold')
    plt.legend(title='Cluster', loc='upper right')
    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, "08_kmeans_clusters_scatter.png"), dpi=300)
    plt.savefig(os.path.join(DASHBOARD_DIR, "08_kmeans_clusters_scatter.png"), dpi=300)
    plt.close()
    
    # Save final customer RFM segmented table
    out_csv = os.path.join(PROCESSED_DIR, "rfm_customer_segments.csv")
    rfm.to_csv(out_csv, index=False)
    print(f"\nFinal RFM and K-Means segmentation saved to: {out_csv} ({rfm.shape})")

if __name__ == "__main__":
    run_customer_segmentation()
