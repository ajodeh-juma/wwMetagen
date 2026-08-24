#!/usr/bin/env python3
import pandas as pd
import argparse
import os
import sys

def main():
    parser = argparse.ArgumentParser(description="Merge individual metric TSVs into a single table")
    parser.add_argument("-i", "--input", nargs='+', required=True, help="List of TSV files to merge")
    parser.add_argument("-o", "--output", required=True, help="Output filename")
    args = parser.parse_args()

    # Read and collect all dataframes
    df_list = []
    for f in args.input:
        try:
            temp_df = pd.read_csv(f, sep='\t')
            if not temp_df.empty:
                df_list.append(temp_df)
        except Exception as e:
            print(f"Warning: Skipping {f} due to error: {e}", file=sys.stderr)

    if not df_list:
        print("No valid data found to merge.")
        sys.exit(1)

    # Concatenate all files
    merged_df = pd.concat(df_list, axis=0, ignore_index=True)

    # Ensure consistent column ordering
    cols = ['sample_name', 'total_reads', 'bacterial_reads', 'viral_reads', 'eukaryote_reads', 'archaea_reads', 'classified_reads', 'unclassified_reads']
    # Filter to only existing columns just in case
    cols = [c for c in cols if c in merged_df.columns]
    merged_df = merged_df[cols].sort_values(by='sample_name')

    # Save
    merged_df.to_csv(args.output, sep='\t', index=False)
    print(f"Successfully merged {len(df_list)} files into {args.output}")

if __name__ == "__main__":
    main()