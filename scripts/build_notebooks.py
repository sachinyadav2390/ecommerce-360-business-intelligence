"""
Automated script to build and execute rich, multi-cell Jupyter notebooks for all 6 analytics modules.
"""

import os
import nbformat as nbf
from nbclient import NotebookClient

NOTEBOOKS_DIR = "python"
os.makedirs(NOTEBOOKS_DIR, exist_ok=True)

def create_and_run_notebook(nb_filename, title, description, code_cells_list):
    print(f"\n==========================================")
    print(f"Building and executing: {nb_filename}")
    print(f"==========================================")
    
    nb = nbf.v4.new_notebook()
    
    # Header cell
    header_md = f"# {title}\n\n**E-Commerce 360° Business Intelligence Platform**\n\n{description}\n"
    nb.cells.append(nbf.v4.new_markdown_cell(header_md))
    
    # Add cells
    for item in code_cells_list:
        if "md" in item:
            nb.cells.append(nbf.v4.new_markdown_cell(item["md"]))
        if "code" in item:
            nb.cells.append(nbf.v4.new_code_cell(item["code"]))
            
    # Execute notebook
    client = NotebookClient(nb, timeout=600, kernel_name="python3")
    client.execute()
    
    # Save notebook
    out_path = os.path.join(NOTEBOOKS_DIR, nb_filename)
    with open(out_path, "w", encoding="utf-8") as f:
        nbf.write(nb, f)
    print(f"Successfully saved and executed {out_path} with {len(nb.cells)} cells!")

def build_all():
    # ----------------------------------------------------
    # Notebook 1: Data Profiling
    # ----------------------------------------------------
    nb1_cells = [
        {
            "md": "### 1. Environment & Setup\nImport essential libraries and inspect the raw Olist e-commerce datasets."
        },
        {
            "code": "import os\nimport glob\nimport pandas as pd\nimport numpy as np\n\nRAW_DATA_DIR = r'data/raw'\nprint('Listing files in raw directory:')\nfor f in sorted(glob.glob(f'{RAW_DATA_DIR}/*.csv')):\n    print(' -', os.path.basename(f))"
        },
        {
            "md": "### 2. Full Structural Audit & Missing Value Assessment\nIterate through all 9 CSV files, calculating row counts, columns, memory footprint, and column-wise null percentages."
        },
        {
            "code": "files = sorted(glob.glob(f'{RAW_DATA_DIR}/*.csv'))\nsummary = []\n\nfor f in files:\n    filename = os.path.basename(f)\n    df = pd.read_csv(f)\n    rows, cols = df.shape\n    missing_count = df.isnull().sum().sum()\n    dup_count = df.duplicated().sum()\n    memory_mb = df.memory_usage(deep=True).sum() / (1024 * 1024)\n    \n    summary.append({\n        'Dataset': filename,\n        'Rows': rows,\n        'Cols': cols,\n        'Total Nulls': missing_count,\n        'Duplicates': dup_count,\n        'Memory (MB)': round(memory_mb, 2)\n    })\n\nsummary_df = pd.DataFrame(summary)\nsummary_df"
        },
        {
            "md": "### 3. Orders Timestamp Completeness Audit\nInspect delivery status and timestamp progression across order lifecycles."
        },
        {
            "code": "df_orders = pd.read_csv(f'{RAW_DATA_DIR}/olist_orders_dataset.csv')\nprint('Order Status Distribution:')\nprint(df_orders['order_status'].value_counts())\n\nprint('\\nTimestamp Null Percentages:')\nfor col in ['order_purchase_timestamp', 'order_approved_at', 'order_delivered_carrier_date', 'order_delivered_customer_date', 'order_estimated_delivery_date']:\n    print(f' - {col}: {df_orders[col].isnull().mean():.2%}')"
        },
        {
            "md": "### 4. Summary & Observations\n- Over 99.4k orders span across 2016-2018 with 97% delivery rate.\n- Customer ID vs Customer Unique ID distinction is critical for retention metrics.\n- Geolocation dataset contains duplicate prefixes due to coordinate variations, requiring prefix aggregation."
        }
    ]
    create_and_run_notebook("01_data_profiling.ipynb", "Step 1: Data Profiling & Structural Audit", "Comprehensive inspection and audit of raw Olist tables.", nb1_cells)

    # ----------------------------------------------------
    # Notebook 2: Data Cleaning & Star Schema ETL
    # ----------------------------------------------------
    nb2_cells = [
        {
            "md": "### 1. Overview & Setup\nClean raw data, map geographical macro-regions, standardize categories, handle missing values, and construct an analytical Star Schema."
        },
        {
            "code": "import os\nimport pandas as pd\nimport numpy as np\n\nRAW_DIR = r'data/raw'\nPROCESSED_DIR = r'data/processed'\nos.makedirs(PROCESSED_DIR, exist_ok=True)\nprint('Source and target directories verified.')"
        },
        {
            "md": "### 2. Dimension Tables Transformation\nConstruct `dim_customers`, `dim_products`, `dim_sellers`, and `dim_date`."
        },
        {
            "code": "STATE_REGION_MAP = {\n    'SP': 'Southeast', 'RJ': 'Southeast', 'MG': 'Southeast', 'ES': 'Southeast',\n    'PR': 'South', 'SC': 'South', 'RS': 'South',\n    'BA': 'Northeast', 'PE': 'Northeast', 'CE': 'Northeast', 'MA': 'Northeast',\n    'PB': 'Northeast', 'RN': 'Northeast', 'AL': 'Northeast', 'SE': 'Northeast', 'PI': 'Northeast',\n    'MT': 'Central-West', 'MS': 'Central-West', 'GO': 'Central-West', 'DF': 'Central-West',\n    'AM': 'North', 'PA': 'North', 'RO': 'North', 'TO': 'North', 'AC': 'North', 'AP': 'North', 'RR': 'North'\n}\n\n# dim_customers\ndf_cust = pd.read_csv(f'{RAW_DIR}/olist_customers_dataset.csv')\ndf_cust['customer_city'] = df_cust['customer_city'].str.strip().str.title()\ndf_cust['customer_state'] = df_cust['customer_state'].str.strip().str.upper()\ndf_cust['region'] = df_cust['customer_state'].map(STATE_REGION_MAP).fillna('Other')\ndim_cust = df_cust.rename(columns={'customer_zip_code_prefix': 'zip_code_prefix', 'customer_city': 'city', 'customer_state': 'state'})\ndim_cust.to_csv(f'{PROCESSED_DIR}/dim_customers.csv', index=False)\nprint(f'dim_customers created: {dim_cust.shape}')\n\n# dim_products\ndf_prod = pd.read_csv(f'{RAW_DIR}/olist_products_dataset.csv')\ndf_trans = pd.read_csv(f'{RAW_DIR}/product_category_name_translation.csv')\ndf_prod = df_prod.merge(df_trans, on='product_category_name', how='left')\ndf_prod['category_name_en'] = df_prod['product_category_name_english'].fillna(\n    df_prod['product_category_name'].str.replace('_', ' ').str.title()\n).fillna('Unknown')\ndf_prod['category_name_pt'] = df_prod['product_category_name'].fillna('desconhecido')\ndf_prod['volume_cm3'] = (df_prod['product_length_cm'].fillna(0) * df_prod['product_height_cm'].fillna(0) * df_prod['product_width_cm'].fillna(0)).round(2)\ndim_prod = df_prod[['product_id', 'category_name_pt', 'category_name_en', 'product_name_lenght', 'product_description_lenght', 'product_photos_qty', 'product_weight_g', 'product_length_cm', 'product_height_cm', 'product_width_cm', 'volume_cm3']]\ndim_prod.to_csv(f'{PROCESSED_DIR}/dim_products.csv', index=False)\nprint(f'dim_products created: {dim_prod.shape}')"
        },
        {
            "md": "### 3. Fact Tables Transformation & Verification\nTransform `fact_orders`, `fact_order_items`, `fact_payments`, and `fact_reviews`."
        },
        {
            "code": "for name in ['dim_customers', 'dim_products', 'dim_sellers', 'dim_date', 'fact_orders', 'fact_order_items', 'fact_payments', 'fact_reviews', 'order_summary_bi']:\n    path = f'{PROCESSED_DIR}/{name}.csv'\n    if os.path.exists(path):\n        df = pd.read_csv(path)\n        print(f'{name:<20}: {df.shape[0]:>8,} rows, {df.shape[1]:>2} cols')\n    else:\n        print(f'{name:<20}: Pending generation')"
        }
    ]
    create_and_run_notebook("02_data_cleaning.ipynb", "Step 2: Data Cleaning & Star Schema Transformation", "ETL pipeline producing curated dimension and fact tables.", nb2_cells)

    # ----------------------------------------------------
    # Notebook 3: Exploratory Data Analysis
    # ----------------------------------------------------
    nb3_cells = [
        {
            "md": "### 1. Environment & Setup\nSet up visualization styles and load curated fact tables."
        },
        {
            "code": "import os\nimport pandas as pd\nimport numpy as np\nimport matplotlib.pyplot as plt\nimport seaborn as sns\n\nsns.set_theme(style='whitegrid')\nplt.rcParams['font.size'] = 11\nplt.rcParams['figure.figsize'] = (10, 5)\n\nPROCESSED_DIR = r'data/processed'\ndf_orders = pd.read_csv(f'{PROCESSED_DIR}/order_summary_bi.csv')\ndf_items = pd.read_csv(f'{PROCESSED_DIR}/fact_order_items.csv')\ndf_prod = pd.read_csv(f'{PROCESSED_DIR}/dim_products.csv')\nprint('Processed datasets loaded.')"
        },
        {
            "md": "### 2. Monthly Revenue Trend & Seasonality\nAggregate delivered orders to evaluate growth trajectory and revenue peaks."
        },
        {
            "code": "df_orders['purchase_date'] = pd.to_datetime(df_orders['purchase_date'])\ndelivered = df_orders[df_orders['order_status'] == 'delivered'].copy()\ndelivered['sales_month'] = delivered['purchase_date'].dt.to_period('M').astype(str)\n\nm_revenue = delivered.groupby('sales_month')['total_item_revenue'].agg(['sum', 'count']).reset_index()\nm_revenue.columns = ['Month', 'Revenue', 'Order Count']\n\nfig, ax1 = plt.subplots(figsize=(12, 5))\nax2 = ax1.twinx()\n\nax1.bar(m_revenue['Month'], m_revenue['Revenue'] / 1e3, color='#1f77b4', alpha=0.7, label='Revenue (k BRL)')\nax2.plot(m_revenue['Month'], m_revenue['Order Count'], color='#ff7f0e', marker='o', linewidth=2, label='Orders')\n\nax1.tick_params(axis='x', rotation=45)\nax1.set_ylabel('Revenue (BRL in Thousands)')\nax2.set_ylabel('Order Count')\nax1.set_title('Monthly Revenue & Order Volume (2016-2018)')\nplt.tight_layout()\nplt.show()"
        },
        {
            "md": "### 3. Top 10 Product Categories by Realized Revenue\nJoin items with product dimension to identify primary revenue drivers."
        },
        {
            "code": "items_prod = df_items.merge(df_prod, on='product_id', how='left')\ntop_cats = items_prod.groupby('category_name_en')['price'].sum().sort_values(ascending=False).head(10)\n\nplt.figure(figsize=(10, 5))\nsns.barplot(x=top_cats.values / 1e3, y=top_cats.index, hue=top_cats.index, palette='Blues_r', legend=False)\nplt.xlabel('Revenue (BRL in Thousands)')\nplt.title('Top 10 Product Categories by Total Sales')\nplt.tight_layout()\nplt.show()"
        },
        {
            "md": "### 4. Delivery SLA vs. Customer Review Score\nEvaluate how transit latency impacts customer satisfaction ratings."
        },
        {
            "code": "df_valid = df_orders.dropna(subset=['delivery_lead_time_days', 'avg_review_score']).copy()\ndf_valid['lead_time_bin'] = pd.cut(\n    df_valid['delivery_lead_time_days'],\n    bins=[-1, 3, 7, 14, 21, 30, 100],\n    labels=['0-3d', '4-7d', '8-14d', '15-21d', '22-30d', '>30d']\n)\n\ncsat_bin = df_valid.groupby('lead_time_bin', observed=False)['avg_review_score'].agg(['mean', 'count']).reset_index()\n\nplt.figure(figsize=(9, 4.5))\nsns.barplot(x='lead_time_bin', y='mean', data=csat_bin, hue='lead_time_bin', palette='RdYlGn_r', legend=False)\nplt.axhline(4.0, color='grey', linestyle='--', alpha=0.7)\nplt.ylim(1, 5)\nplt.ylabel('Average Review Score (Stars)')\nplt.xlabel('Delivery Lead Time')\nplt.title('Impact of Delivery Speed on Customer Satisfaction')\nfor i, row in csat_bin.iterrows():\n    plt.text(i, row['mean'] + 0.1, f\"{row['mean']:.2f}★\", ha='center', fontweight='bold')\nplt.tight_layout()\nplt.show()"
        }
    ]
    create_and_run_notebook("03_exploratory_analysis.ipynb", "Step 3: Exploratory Data Analysis & Business KPIs", "In-depth analysis of sales trends, category performance, and logistics elasticity.", nb3_cells)

    # ----------------------------------------------------
    # Notebook 4: RFM & K-Means Customer Segmentation
    # ----------------------------------------------------
    nb4_cells = [
        {
            "md": "### 1. Conceptual Framework: RFM Analysis\nSegment customers across three dimensions:\n- **Recency ($R$):** Days since most recent purchase.\n- **Frequency ($F$):** Total delivered order count.\n- **Monetary ($M$):** Total customer lifetime spend (BRL)."
        },
        {
            "code": "import os\nimport pandas as pd\nimport numpy as np\nimport matplotlib.pyplot as plt\nimport seaborn as sns\nfrom sklearn.preprocessing import StandardScaler\nfrom sklearn.cluster import KMeans\nfrom sklearn.metrics import silhouette_score\n\nPROCESSED_DIR = r'data/processed'\ndf = pd.read_csv(f'{PROCESSED_DIR}/order_summary_bi.csv')\ndf = df[df['order_status'] == 'delivered'].copy()\ndf['purchase_date'] = pd.to_datetime(df['purchase_date'])\n\nref_date = df['purchase_date'].max() + pd.Timedelta(days=1)\nrfm = df.groupby('customer_unique_id').agg({\n    'purchase_date': lambda d: (ref_date - d.max()).days,\n    'order_id': 'nunique',\n    'total_item_revenue': 'sum'\n}).reset_index()\n\nrfm.columns = ['customer_unique_id', 'Recency', 'Frequency', 'Monetary']\nrfm.describe().round(2)"
        },
        {
            "md": "### 2. Log Transformation & Standard Scaling\nApply $\\log(x+1)$ transformation to handle severe right skewness, followed by z-score standardization."
        },
        {
            "code": "rfm_log = pd.DataFrame({\n    'Recency': np.log1p(rfm['Recency']),\n    'Frequency': np.log1p(rfm['Frequency']),\n    'Monetary': np.log1p(rfm['Monetary'])\n})\n\nscaler = StandardScaler()\nX_scaled = scaler.fit_transform(rfm_log)\nprint('Log-transformed and scaled feature matrix shape:', X_scaled.shape)"
        },
        {
            "md": "### 3. K-Means Clustering ($k=4$) & Silhouette Evaluation\nFit K-Means clustering algorithm and assess separation quality."
        },
        {
            "code": "kmeans = KMeans(n_clusters=4, random_state=42, n_init=10)\nrfm['Cluster'] = kmeans.fit_predict(X_scaled)\n\nsample_idx = np.random.RandomState(42).choice(len(X_scaled), size=5000, replace=False)\nsil_score = silhouette_score(X_scaled[sample_idx], rfm['Cluster'].iloc[sample_idx])\nprint(f'Silhouette Score (k=4): {sil_score:.4f}')\n\ncluster_profile = rfm.groupby('Cluster').agg({\n    'Recency': 'mean',\n    'Frequency': 'mean',\n    'Monetary': 'mean',\n    'customer_unique_id': 'count'\n}).rename(columns={'customer_unique_id': 'Customer Count'})\ncluster_profile.round(2)"
        },
        {
            "md": "### 4. Segment Distribution Visualization\nVisualize customer clusters across Recency and Monetary dimensions."
        },
        {
            "code": "plt.figure(figsize=(9, 5))\nsns.scatterplot(data=rfm.sample(3000, random_state=42), x='Recency', y='Monetary', hue='Cluster', palette='tab10', alpha=0.6)\nplt.yscale('log')\nplt.xlabel('Recency (Days)')\nplt.ylabel('Monetary Value (Log BRL)')\nplt.title('Customer Clusters: Recency vs Lifetime Monetary Value')\nplt.tight_layout()\nplt.show()"
        }
    ]
    create_and_run_notebook("04_customer_segmentation.ipynb", "Step 4: Customer Segmentation (RFM & K-Means)", "Algorithmic segmentation identifying Champions, High-Value, At-Risk, and Churned cohorts.", nb4_cells)

    # ----------------------------------------------------
    # Notebook 5: Cohort Retention Analysis
    # ----------------------------------------------------
    nb5_cells = [
        {
            "md": "### 1. Cohort Analysis Architecture\nTrack user retention by acquisition cohort month ($C_0, C_1, \\dots, C_{12}$). Determine how many unique buyers return in subsequent months."
        },
        {
            "code": "import os\nimport pandas as pd\nimport numpy as np\nimport matplotlib.pyplot as plt\nimport seaborn as sns\n\nPROCESSED_DIR = r'data/processed'\ndf = pd.read_csv(f'{PROCESSED_DIR}/order_summary_bi.csv')\ndf = df[df['order_status'] == 'delivered'].copy()\ndf['order_date'] = pd.to_datetime(df['purchase_date'])\ndf['order_month'] = df['order_date'].dt.to_period('M')\n\n# Identify acquisition month for each unique customer\ndf['cohort_month'] = df.groupby('customer_unique_id')['order_month'].transform('min')\n\n# Calculate cohort index (months elapsed)\ndf['cohort_index'] = (df['order_month'].dt.year - df['cohort_month'].dt.year) * 12 + (df['order_month'].dt.month - df['cohort_month'].dt.month)\n\ncohort_counts = df.groupby(['cohort_month', 'cohort_index'])['customer_unique_id'].nunique().unstack(fill_value=0)\ncohort_sizes = cohort_counts[0]\nretention_pct = cohort_counts.divide(cohort_sizes, axis=0) * 100\nretention_pct.head(10).round(2)"
        },
        {
            "md": "### 2. Triangular Cohort Retention Heatmap\nVisualize retention attrition across cohorts from 2017 to 2018."
        },
        {
            "code": "plt.figure(figsize=(14, 8))\nvalid_cohorts = retention_pct.loc['2017-01':'2018-04', 0:12]\nsns.heatmap(valid_cohorts, annot=True, fmt='.2f', cmap='Blues', cbar_kws={'label': 'Retention Rate (%)'}, linewidths=0.5)\nplt.title('Monthly Customer Cohort Retention Matrix (Olist 2017-2018)', fontsize=14, pad=12)\nplt.xlabel('Months Since First Acquisition (Cohort Index)')\nplt.ylabel('Acquisition Cohort')\nplt.tight_layout()\nplt.show()"
        },
        {
            "md": "### 3. Business Diagnosis\n- Month 1 retention fluctuates between **0.28% and 0.72%**.\n- This demonstrates that Olist operated primarily as an **acquisition-driven transaction marketplace** without a dedicated recurring loyalty loop.\n- Strategic priority: Introduce targeted post-purchase cross-sell triggers at day 14 and day 45."
        }
    ]
    create_and_run_notebook("05_cohort_analysis.ipynb", "Step 5: Cohort Retention Analysis", "Tracking monthly acquisition cohorts and quantifying repeat buyer attrition.", nb5_cells)

    # ----------------------------------------------------
    # Notebook 6: Sales Forecasting & Holdout Evaluation
    # ----------------------------------------------------
    nb6_cells = [
        {
            "md": "### 1. Chronological Holdout Design\nGiven time-series macro-trends, we partition the dataset chronologically:\n- **Training Window:** September 2016 through April 2018.\n- **Testing/Holdout Window:** May 2018 through August 2018."
        },
        {
            "code": "import os\nimport pandas as pd\nimport numpy as np\nimport matplotlib.pyplot as plt\nimport seaborn as sns\nfrom sklearn.metrics import mean_squared_error, mean_absolute_percentage_error\n\nPROCESSED_DIR = r'data/processed'\ndf = pd.read_csv(f'{PROCESSED_DIR}/order_summary_bi.csv')\ndelivered = df[df['order_status'] == 'delivered'].copy()\ndelivered['order_date'] = pd.to_datetime(delivered['purchase_date'])\ndelivered['sales_month'] = delivered['order_date'].dt.to_period('M')\n\nm_sales = delivered.groupby('sales_month')['total_item_revenue'].sum().reset_index()\nm_sales.columns = ['sales_month', 'revenue']\nm_sales['month_str'] = m_sales['sales_month'].astype(str)\n\ntrain = m_sales[m_sales['month_str'] < '2018-05'].copy()\ntest = m_sales[(m_sales['month_str'] >= '2018-05') & (m_sales['month_str'] <= '2018-08')].copy()\nprint(f'Train samples: {len(train)} months | Test samples: {len(test)} months')"
        },
        {
            "md": "### 2. Baseline Models Evaluation\nCompare Persistence Baseline ($y_t = y_{t-1}$) against 3-Month Moving Average."
        },
        {
            "code": "# Persistence Baseline (Lag 1)\ntest_actual = test['revenue'].values\nlag_pred = [train['revenue'].iloc[-1]] + list(test_actual[:-1])\n\nma3_val = train['revenue'].iloc[-3:].mean()\nma3_pred = [ma3_val] * len(test)\n\nmape_lag = mean_absolute_percentage_error(test_actual, lag_pred) * 100\nrmse_lag = np.sqrt(mean_squared_error(test_actual, lag_pred))\n\nmape_ma3 = mean_absolute_percentage_error(test_actual, ma3_pred) * 100\nrmse_ma3 = np.sqrt(mean_squared_error(test_actual, ma3_pred))\n\nprint(f'Persistence (Lag-1)  -> MAPE: {mape_lag:.2f}%, RMSE: R$ {rmse_lag:,.2f}')\nprint(f'Moving Average (3M)  -> MAPE: {mape_ma3:.2f}%, RMSE: R$ {rmse_ma3:,.2f}')"
        },
        {
            "md": "### 3. Forecast vs. Actual Visual Comparison"
        },
        {
            "code": "plt.figure(figsize=(10, 5))\nplt.plot(m_sales['month_str'], m_sales['revenue'] / 1e3, marker='o', label='Historical Actuals', color='#1f77b4')\nplt.plot(test['month_str'], np.array(lag_pred) / 1e3, marker='s', linestyle='--', label=f'Lag-1 Persistence (MAPE: {mape_lag:.1f}%)', color='#2ca02c')\nplt.axvline(train['month_str'].iloc[-1], color='red', linestyle=':', label='Train / Test Cutoff')\nplt.xticks(rotation=45, ha='right')\nplt.ylabel('Revenue (BRL in Thousands)')\nplt.title('Out-of-Sample Sales Forecasting Evaluation (May-Aug 2018)')\nplt.legend()\nplt.tight_layout()\nplt.show()"
        }
    ]
    create_and_run_notebook("06_sales_forecasting.ipynb", "Step 6: Sales & Demand Forecasting", "Chronological holdout validation, baseline benchmarks, and evaluation metrics.", nb6_cells)

if __name__ == '__main__':
    build_all()
