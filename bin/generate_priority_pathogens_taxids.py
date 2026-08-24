#!/usr/bin/env python3

import argparse
from Bio import Entrez
import pandas as pd
import time
import sys
import os

def get_args():
    parser = argparse.ArgumentParser(description="Generate TaxIDs for priority pathogens with optional strain expansion.")
    parser.add_argument('--input', required=True, 
                        help="Text file with pathogen names (one per line)")
    parser.add_argument('--email', required=True, 
                        help="NCBI Entrez email")
    parser.add_argument('--api_key', 
                        help="NCBI API key")
    parser.add_argument('--expand', action='store_true',
                        help="If set, expand species to all descendant strain/isolate TaxIDs")
    parser.add_argument('--max_strains', type=int, default=10000,
                        help="Maximum number of strains to retrieve per pathogen (default: 10000)")
    parser.add_argument('--output', default="priority_pathogens_taxids.tsv", 
                        help="Output TSV filename")
    return parser.parse_args()

def get_pathogen_data(name, email, expand=False, max_strains=10000, api_key=None):
    """Retrieves Species TaxID and optionally expands to descendant strains."""
    Entrez.email = email
    try:
        # 1. Search for the primary TaxID
        search_handle = Entrez.esearch(db="taxonomy", term=name, api_key=api_key)
        search_results = Entrez.read(search_handle)
        search_handle.close()

        if not search_results["IdList"]:
            return None

        primary_id = search_results["IdList"][0]

        # 2. Return only the primary ID if expansion is disabled
        if not expand:
            fetch_handle = Entrez.efetch(db="taxonomy", id=primary_id, api_key=api_key)
            record = Entrez.read(fetch_handle)[0]
            fetch_handle.close()
            return [{"TaxID": record["TaxId"], "Name": record["ScientificName"], "Search_Term": name}]

        # 3. Expansion Logic
        expand_query = f"txid{primary_id}[Organism:exp]"
        expand_handle = Entrez.esearch(db="taxonomy", term=expand_query, retmax=max_strains, api_key=api_key)
        id_list = Entrez.read(expand_handle)["IdList"]
        expand_handle.close()

        results = []
        chunk_size = 500
        for i in range(0, len(id_list), chunk_size):
            chunk = id_list[i:i + chunk_size]
            fetch_handle = Entrez.efetch(db="taxonomy", id=",".join(chunk), api_key=api_key)
            records = Entrez.read(fetch_handle)
            fetch_handle.close()
            
            for r in records:
                results.append({
                    "TaxID": r["TaxId"], 
                    "Name": r["ScientificName"], 
                    "Search_Term": name
                })
        return results

    except Exception as e:
        print(f"  ! Error processing '{name}': {e}")
        return None

def main():
    args = get_args()
    
    if not os.path.exists(args.input):
        print(f"Error: Input file '{args.input}' not found.")
        sys.exit(1)

    with open(args.input, 'r') as f:
        pathogen_names = [line.strip() for line in f if line.strip()]

    print(f"Processing {len(pathogen_names)} pathogens (Expand: {args.expand}, Max Strains: {args.max_strains})...")
    
    all_results = []
    for i, name in enumerate(pathogen_names):
        print(f"[{i+1}/{len(pathogen_names)}] {name}...")
        data = get_pathogen_data(name, args.email, args.expand, args.max_strains, args.api_key)
        
        if data:
            all_results.extend(data)
            print(f"  - Retrieved {len(data)} TaxID(s)")
        
        time.sleep(0.3 if args.api_key else 1.0)

    if all_results:
        df = pd.DataFrame(all_results)
        df.to_csv(args.output, sep="\t", index=False, header=False)
        print(f"\nSuccess! Total TaxIDs saved: {len(df)} to {args.output}")

if __name__ == "__main__":
    main()