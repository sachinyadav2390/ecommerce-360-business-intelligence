"""
E-COMMERCE 360° BUSINESS INTELLIGENCE
Step 6: Time-Series Order & Revenue Forecasting Experiment
Methodology: Chronological Holdout Set Evaluation (No Random Splitting)
"""

import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.linear_model import Ridge
from sklearn.metrics import mean_absolute_error, mean_squared_error, mean_absolute_percentage_error

plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams['font.family'] = 'DejaVu Sans'

PROCESSED_DIR = r"data\processed"
REPORT_DIR = r"reports"
DASHBOARD_DIR = r"powerbi\dashboard_screenshots"

os.makedirs(REPORT_DIR, exist_ok=True)
os.makedirs(DASHBOARD_DIR, exist_ok=True)

def run_sales_forecasting():
    print("Loading data for sales & demand forecasting...")
    bi_orders = pd.read_csv(os.path.join(PROCESSED_DIR, "order_summary_bi.csv"))
    delivered = bi_orders[bi_orders['order_status'] == 'delivered'].copy()
    delivered['purchase_date'] = pd.to_datetime(delivered['purchase_date'])
    
    # Aggregate monthly order counts
    monthly = delivered.groupby(delivered['purchase_date'].dt.to_period('M')).agg(
        orders=('order_id', 'count'),
        revenue=('total_item_revenue', 'sum')
    ).reset_index()
    monthly['year_month'] = monthly['purchase_date'].astype(str)
    
    # Filter stable operational period (2017-01 to 2018-08)
    monthly = monthly[(monthly['year_month'] >= '2017-01') & (monthly['year_month'] <= '2018-08')].reset_index(drop=True)
    
    print(f"Total time-series observations: {len(monthly)} months")
    
    # Feature Engineering: Temporal Lags & Rolling Statistics
    df_ts = monthly[['year_month', 'orders', 'revenue']].copy()
    df_ts['lag_1'] = df_ts['orders'].shift(1)
    df_ts['lag_2'] = df_ts['orders'].shift(2)
    df_ts['lag_3'] = df_ts['orders'].shift(3)
    df_ts['rolling_mean_3'] = df_ts['orders'].shift(1).rolling(window=3).mean()
    df_ts['time_step'] = np.arange(len(df_ts))
    
    # Drop warm-up lag rows
    df_ts = df_ts.dropna().reset_index(drop=True)
    
    # Chronological Holdout Split (Hold out last 4 months: 2018-05 to 2018-08)
    test_size = 4
    train = df_ts.iloc[:-test_size].copy()
    test = df_ts.iloc[-test_size:].copy()
    
    print(f"Training Window: {train['year_month'].min()} to {train['year_month'].max()} ({len(train)} months)")
    print(f"Holdout Test Window: {test['year_month'].min()} to {test['year_month'].max()} ({len(test)} months)")
    
    features = ['time_step', 'lag_1', 'lag_2', 'rolling_mean_3']
    X_train, y_train = train[features], train['orders']
    X_test, y_test = test[features], test['orders']
    
    # Model 1: Naive Seasonal / Persistence Baseline (Forecast = Lag 1)
    naive_pred = test['lag_1']
    
    # Model 2: Moving Average Baseline (Forecast = rolling_mean_3)
    ma_pred = test['rolling_mean_3']
    
    # Model 3: Autoregressive Machine Learning Model (Ridge Regression)
    model = Ridge(alpha=1.0)
    model.fit(X_train, y_train)
    ml_pred = model.predict(X_test)
    
    # Evaluation Metrics
    def evaluate(y_true, y_pred, name):
        mae = mean_absolute_error(y_true, y_pred)
        rmse = np.sqrt(mean_squared_error(y_true, y_pred))
        mape = mean_absolute_percentage_error(y_true, y_pred) * 100.0
        return {"Model": name, "MAE (Orders)": round(mae, 1), "RMSE (Orders)": round(rmse, 1), "MAPE (%)": round(mape, 2)}
    
    eval_results = [
        evaluate(y_test, naive_pred, "Baseline 1: Persistence (Lag 1)"),
        evaluate(y_test, ma_pred, "Baseline 2: 3-Month Moving Average"),
        evaluate(y_test, ml_pred, "Trained Model: Autoregressive Ridge")
    ]
    eval_df = pd.DataFrame(eval_results)
    print("\n--- CHRONOLOGICAL HOLDOUT MODEL EVALUATION ---")
    print(eval_df.to_string(index=False))
    
    # Visualization: Actual vs Predicted on Holdout
    plt.figure(figsize=(12, 6))
    
    # Full history
    plt.plot(df_ts['year_month'], df_ts['orders'], marker='o', color='#333333', linewidth=2.5, label='Actual Monthly Orders')
    
    # Holdout predictions
    test_months = test['year_month']
    plt.plot(test_months, naive_pred, marker='^', linestyle='--', color='#ff7f0e', linewidth=2, label='Baseline: Lag-1')
    plt.plot(test_months, ma_pred, marker='d', linestyle='--', color='#2ca02c', linewidth=2, label='Baseline: 3M-MA')
    plt.plot(test_months, ml_pred, marker='s', linestyle='-', color='#d62728', linewidth=2.5, label='Forecast: Autoregressive Model')
    
    # Shaded holdout region
    plt.axvspan(test_months.iloc[0], test_months.iloc[-1], color='#e2e2e2', alpha=0.4, label='Chronological Holdout Set')
    
    plt.title("E-Commerce Monthly Order Volume Forecasting Experiment", fontsize=14, weight='bold', pad=15)
    plt.xlabel("Month", fontweight='bold', labelpad=10)
    plt.ylabel("Delivered Orders Count", fontweight='bold', labelpad=10)
    plt.xticks(rotation=45)
    plt.legend(loc='upper left', frameon=True)
    plt.tight_layout()
    
    forecast_chart_path = os.path.join(REPORT_DIR, "10_sales_forecasting_holdout.png")
    plt.savefig(forecast_chart_path, dpi=300)
    plt.savefig(os.path.join(DASHBOARD_DIR, "10_sales_forecasting_holdout.png"), dpi=300)
    plt.close()
    print(f"\nForecasting evaluation chart saved to: {forecast_chart_path}")

if __name__ == "__main__":
    run_sales_forecasting()
