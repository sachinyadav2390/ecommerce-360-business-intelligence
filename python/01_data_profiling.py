"""
E-COMMERCE 360° BUSINESS INTELLIGENCE
Step 1: Data Profiling & Structural Audit
"""

import os
import glob
import pandas as pd
import numpy as np

RAW_DATA_DIR = r"data\raw"

def profile_dataset():
    print("=" * 80)
    print("OLIST DATASET PROFILING AUDIT REPORT")
    print("=" * 80)
    
    files = glob.glob(os.path.join(RAW_DATA_DIR, "*.csv"))
    summary = []
    
    for f in sorted(files):
        filename = os.path.basename(f)
        df = pd.read_csv(f)
        rows, cols = df.shape
        missing_count = df.isnull().sum().sum()
        dup_count = df.duplicated().sum()
        memory_mb = df.memory_usage(deep=True).sum() / (1024 * 1024)
        
        summary.append({
            "File Name": filename,
            "Rows": f"{rows:,}",
            "Columns": cols,
            "Total Missing Values": f"{missing_count:,}",
            "Duplicate Rows": dup_count,
            "Memory (MB)": f"{memory_mb:.2f}"
        })
        
        print(f"\n--- {filename} ---")
        print(f"Shape: {rows:,} rows, {cols} columns | Memory: {memory_mb:.2f} MB")
        print("Columns & Missing Values:")
        for col in df.columns:
            null_cnt = df[col].isnull().sum()
            null_pct = 100.0 * null_cnt / rows
            dtype = df[col].dtype
            print(f"  - {col} ({dtype}): {null_cnt:,} nulls ({null_pct:.2f}%)")
    
    summary_df = pd.DataFrame(summary)
    print("\n" + "=" * 80)
    print("PROFILING EXECUTIVE SUMMARY TABLE:")
    print("=" * 80)
    print(summary_df.to_string(index=False))

if __name__ == "__main__":
    profile_dataset()
