#!/usr/bin/env python3
"""
Merge mpa-style Kraken/Bracken tables into a single table with clean sample names.
"""

import os
import logging
import argparse
import textwrap
import pandas as pd

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %I:%M:%S %p'
)

def parse_args():
    parser = argparse.ArgumentParser(
        prog="merge_mpa_tables.py",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description=textwrap.dedent('''\
            Performs a table join on one or more kraken2 mpa-styled report files.
            Optimized for large datasets and clean sample naming.
            ''')
    )
    parser.add_argument("-i", "--input", nargs="+", required=True,
                        help="Input MPA files (separated by space)")
    parser.add_argument('--prefix', type=str, required=True,
                        help="Prefix for the output file")
    parser.add_argument('--outdir', type=str, default=".",
                        help="Output directory")
    return parser.parse_args()

def clean_sample_name(filename):
    """
    Extracts only the sample name, removing path and common extensions.
    Example: path/to/Sample_01.mpa.txt -> Sample_01
    """
    base = os.path.basename(filename)
    # Split by dots and take the first part, or handle common multi-part extensions
    # This removes .mpa.txt, .report, .bracken, etc.
    sample_name = base.split('.')[0]
    return sample_name

def merge_mpa(input_files, prefix, outdir):
    data_frames = []
    
    logging.info(f"Processing {len(input_files)} files...")

    for f in input_files:
        if not os.path.exists(f) or os.path.getsize(f) == 0:
            logging.warning(f"Skipping empty or missing file: {f}")
            continue
        
        sample = clean_sample_name(f)
        
        try:
            # MPA files usually have two columns: [Taxonomy, Abundance]
            # We read with no header because some MPA files have comment lines
            df = pd.read_csv(
                f, 
                sep='\t', 
                comment='#', 
                header=None, 
                names=['clade_name', sample],
                index_col='clade_name'
            )
            data_frames.append(df)
        except Exception as e:
            logging.error(f"Failed to process {f}: {e}")

    if not data_frames:
        logging.error("No valid data found to merge.")
        return

    # Use concat for efficiency instead of merge in a loop
    # 'outer' join ensures we keep all clades found in any sample
    logging.info("Merging tables...")
    merged_df = pd.concat(data_frames, axis=1, join='outer')

    # Fill NaNs with 0 (clade not present in sample)
    merged_df = merged_df.fillna(0)

    # Sort columns (sample names) alphabetically
    sorted_columns = sorted(merged_df.columns)
    merged_df = merged_df[sorted_columns]

    # Handle output directory
    if not os.path.exists(outdir):
        os.makedirs(outdir)

    output_path = os.path.join(outdir, f"{prefix}_merged_abundance.txt")
    
    # Save with taxonomy as the first column
    merged_df.to_csv(output_path, sep='\t', index_label='clade_name')
    logging.info(f"Successfully saved merged table to: {output_path}")

def main():
    args = parse_args()
    merge_mpa(input_files=args.input, prefix=args.prefix, outdir=args.outdir)

if __name__ == '__main__':
    main()