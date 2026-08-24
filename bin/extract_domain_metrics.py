#!/usr/bin/env python3
import argparse
import sys
import os

def extract_domain_metrics(report_path):
    # Mapping NCBI TaxIDs to domain categories
    # 0: Unclassified, 1: Root (Classified), 2: Bacteria, 10239: Viruses, 2759: Eukaryota, 13: Archaea
    targets = {0: 'unclassified', 1: 'classified', 2: 'bacteria', 10239: 'viral', 2759: 'eukaryote', 13: 'archaea'}
    results = {v: 0 for v in targets.values()}
    
    found_count = 0
    total_to_find = len(targets)

    try:
        with open(report_path, 'r', buffering=1024*1024) as f:
            for line in f:
                parts = line.split('\t', 5)
                if len(parts) < 5:
                    continue
                
                taxid = int(parts[4])
                if taxid in targets:
                    results[targets[taxid]] = int(parts[1])
                    found_count += 1
                    
                    if found_count == total_to_find:
                        break
    except Exception as e:
        print(f"Error parsing {report_path}: {e}", file=sys.stderr)

    total = results['classified'] + results['unclassified']
    return [total, results['bacteria'], results['viral'], results['eukaryote'], results['archaea'], results['classified'], results['unclassified']]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", required=True, help="Input report file")
    parser.add_argument("-s", "--sample", required=True, help="Sample name")
    parser.add_argument("-o", "--outdir", required=True, help="Output directory") # Changed to outdir
    args = parser.parse_args()

    # 1. Ensure the output directory exists
    if not os.path.exists(args.outdir):
        os.makedirs(args.outdir, exist_ok=True)

    # 2. Construct the output filename automatically using the sample name
    output_filename = f"{args.sample}_domain_metrics.tsv"
    output_path = os.path.join(args.outdir, output_filename)

    data = extract_domain_metrics(args.input)
    
    output_line = f"{args.sample}\t" + "\t".join(map(str, data)) + "\n"
    
    # 3. Write to the new constructed path
    with open(output_path, 'w') as out:
        out.write("sample_name\ttotal_reads\tbacterial_reads\tviral_reads\teukaryote_reads\tarchaea_reads\tclassified_reads\tunclassified_reads\n")
        out.write(output_line)

if __name__ == "__main__":
    main()