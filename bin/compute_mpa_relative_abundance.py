#!/usr/bin/env python3
import pandas as pd
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="Normalize MPA counts to whole-number RPM/CPM.")
    parser.add_argument("-m", "--mpa", required=True, help="Merged MPA file (raw counts)")
    parser.add_argument("-s", "--summary", required=True, help="Summary metrics file (TSV)")
    parser.add_argument("-o", "--output", required=True, help="Output filename")
    parser.add_argument("--scale", type=float, default=1000000, help="Scaling factor (default: 1M)")
    args = parser.parse_args()

    # 1. Load Summary Metrics
    try:
        df_summary = pd.read_csv(args.summary, sep='\t')
        if 'classified_reads' not in df_summary.columns:
            sys.exit("Error: Summary file missing 'classified_reads' column.")
        read_map = df_summary.set_index('sample_name')['classified_reads'].to_dict()
    except Exception as e:
        sys.exit(f"Error reading summary file: {e}")

    # 2. Load MPA
    try:
        df_mpa = pd.read_csv(args.mpa, sep='\t')
        sample_cols = df_mpa.columns[1:]
    except Exception as e:
        sys.exit(f"Error reading MPA file: {e}")

    # 3. Vectorized Normalization, Scaling, and Rounding
    for sample in sample_cols:
        if sample in read_map:
            denominator = read_map[sample]
            if denominator > 0:
                # Perform computation: (count / classified) * scale
                # Then round to 0 decimal places and convert to integer
                df_mpa[sample] = ((df_mpa[sample] / denominator) * args.scale).round(0).astype(int)
            else:
                df_mpa[sample] = 0
        else:
            print(f"Warning: Sample {sample} not found in summary metrics.")

    # 4. Save result
    df_mpa.to_csv(args.output, sep='\t', index=False)
    print(f"Normalized and rounded to whole numbers. Output saved to {args.output}")

if __name__ == "__main__":
    main()