#!/usr/bin/env python3

import os
import argparse
import pandas as pd

def main():
    parser = argparse.ArgumentParser(description='Process a single sample coverage file.')
    parser.add_argument('--input_file', required=True, help='Path to a single samtools coverage .txt file')
    parser.add_argument('--pathogen_tsv', required=True, help='Path to metadata TSV')
    parser.add_argument('--sample_id', required=True, help='ID of the current sample')
    parser.add_argument('--output', required=True, help='Output filename')
    args = parser.parse_args()

    # 1. Load Metadata
    meta = pd.read_csv(args.pathogen_tsv, sep='\t')
    # Accession -> Pathogen Name (e.g., NC_003996.3 -> Influenza_A)
    accession_to_pathogen = dict(zip(meta['Accession'], meta['Pathogen']))
    
    # 2. Process the Single Coverage File
    df = pd.read_csv(args.input_file, sep='\t')
    
    # Clean up the #rname to get the Accession
    df['Accession'] = df['#rname'].apply(lambda x: x.split(' ')[0])
    df['Pathogen_Name'] = df['Accession'].map(accession_to_pathogen)
    
    # Drop rows that didn't map to our database pathogens
    df = df.dropna(subset=['Pathogen_Name'])

    # 3. Aggregate Segments (Crucial for Influenza/Oropouche)
    agg = df.groupby('Pathogen_Name').agg({
        'numreads': 'sum',
        'covbases': 'sum',
        'endpos': 'sum'
    }).reset_index()

    # 4. Compute Sample-Specific Metrics
    # total_reads here refers to the total reads mapped to the pathogens fasta for this sample
    total_reads = agg['numreads'].sum()
    
    agg['CPM'] = (agg['numreads'] / (total_reads + 1)) * 1e6
    agg['Breadth_Pct'] = (agg['covbases'] / agg['endpos']) * 100
    agg['Sample_ID'] = args.sample_id

    # 5. Export partial CSV

    outdir = os.path.dirname(args.output)

    if not os.path.exists(outdir):
        os.makedirs(outdir)

    agg.to_csv(args.output, index=False)

if __name__ == "__main__":
    main()