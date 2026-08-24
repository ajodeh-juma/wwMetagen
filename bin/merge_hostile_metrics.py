#!/usr/bin/env python3
import pandas as pd
import argparse
import os
import sys

def main():
    parser = argparse.ArgumentParser(description="Merge individual Hostile metric TSVs")
    parser.add_argument("-i", "--input", nargs='+', required=True, help="List of TSV files")
    parser.add_argument("-o", "--output", required=True, help="Output filename")
    args = parser.parse_args()

    df_list = []
    for f in args.input:
        try:
            df = pd.read_csv(f, sep='\t')
            if not df.empty:
                df_list.append(df)
        except Exception as e:
            print(f"Warning: Skipping {f} due to error: {e}", file=sys.stderr)

    if not df_list:
        print("No valid data found to merge.")
        sys.exit(1)

    # Combine all samples
    merged_df = pd.concat(df_list, axis=0, ignore_index=True)

    # Maintain strict column order for biosecurity reporting
    cols = ['sample_name', 'reads_in', 'reads_out', 'reads_removed', 'reads_removed_proportion']
    merged_df = merged_df[cols].sort_values(by='sample_name')

    # Save to TSV
    merged_df.to_csv(args.output, sep='\t', index=False)
    print(f"Successfully merged {len(df_list)} Hostile reports into {args.output}")

if __name__ == "__main__":
    main()