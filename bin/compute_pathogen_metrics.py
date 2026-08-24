#!/usr/bin/env python3
import pandas as pd
import argparse
import os
import sys

def main():
    parser = argparse.ArgumentParser(description="Merge Minimap2 coverage with NCBI metadata")
    parser.add_argument("-m", "--metadata", required=True, help="NCBI metadata.tsv file")
    parser.add_argument("-c", "--coverage", required=True, help="Minimap2/Samtools coverage file")
    parser.add_argument("-s", "--sample_id", required=True, help="Sample identifier")
    parser.add_argument("-o", "--outdir", required=True, help="Output directory")
    args = parser.parse_args()

    # 1. Load Data
    try:
        # NCBI metadata often has spaces or tabs; check format
        meta_df = pd.read_csv(args.metadata, sep='\t')
        cov_df = pd.read_csv(args.coverage, sep='\t')
    except Exception as e:
        print(f"Error reading input files: {e}", file=sys.stderr)
        sys.exit(1)

    # 2. Merge Tables
    # Minimap2 uses '#rname' for the accession; Metadata uses 'RefSeq seq accession'
    merged = pd.merge(
        cov_df, 
        meta_df, 
        left_on='#rname', 
        right_on='RefSeq seq accession', 
        how='inner' # Automatically drops rows not in our pathogen database
    )

    if merged.empty:
        print(f"Warning: No matches found for sample {args.sample_id}. Output will be empty.")

    # 3. Aggregate reads for the same organism
    # This handles organisms with multiple chromosomes, segments, or plasmids
    agg = merged.groupby(['Organism Name', 'Organism Taxonomic ID', 'Assembly Accession']).agg({
        'numreads': 'sum',
        'covbases': 'sum',
        'endpos': 'sum'  # This represents the total reference length of all segments
    }).reset_index()

    # 4. Compute Sample-Specific Metrics
    # total_reads here represents the total number of reads mapped to pathogens in this sample
    total_mapped_reads = agg['numreads'].sum()
    
    # Calculate CPM (Counts Per Million)
    agg['CPM'] = (agg['numreads'] / (total_mapped_reads + 1)) * 1e6
    
    # Calculate Breadth of Coverage Percentage
    agg['Breadth_Pct'] = (agg['covbases'] / agg['endpos']) * 100
    
    # Add Sample Metadata
    agg['Sample_ID'] = args.sample_id

    # 5. Output Results
    if not os.path.exists(args.outdir):
        os.makedirs(args.outdir, exist_ok=True)

    output_path = os.path.join(args.outdir, f"{args.sample_id}_metrics.csv")
    agg.to_csv(output_path, sep=',', index=False)
    print(f"Successfully created: {output_path}")

if __name__ == "__main__":
    main()