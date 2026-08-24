#!/usr/bin/env python3
import json
import pandas as pd
import argparse
import os

def main():
    parser = argparse.ArgumentParser(description="Extract fastp metrics to TSV")
    parser.add_argument('--input',  required=True, help="Path to fastp.json file")
    parser.add_argument('--prefix', required=True, help="Sample name/prefix")
    parser.add_argument('--outdir', default=".",   help="Output directory")
    args = parser.parse_args()

    # Load JSON
    with open(args.input, 'r') as f:
        data = json.load(f)

    # Extract specific metrics
    metrics = {
        'sample_name': args.prefix,
        'reads_before': data['summary']['before_filtering']['total_reads'],
        'reads_after': data['summary']['after_filtering']['total_reads'],
        'duplication_rate': data['duplication'].get('rate', 0), # Using .get for safety
        'gc_content_after': data['summary']['after_filtering']['gc_content']
    }

    # Convert to DataFrame
    df = pd.DataFrame([metrics])

    # Ensure output directory exists
    os.makedirs(args.outdir, exist_ok=True)
    
    # Save as TSV
    output_path = os.path.join(args.outdir, f"{args.prefix}_summary.tsv")
    df.to_csv(output_path, sep='\t', index=False)

if __name__ == "__main__":
    main()