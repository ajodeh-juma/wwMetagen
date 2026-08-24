#!/usr/bin/env python3
import argparse
import pandas as pd
import numpy as np
import pysam
import os

def parse_args():
    parser = argparse.ArgumentParser(description="Calculate population diversity metrics with windowed output.")
    parser.add_argument("-v", "--vcf", required=True, help="Path to indexed VCF (.vcf.gz)")
    parser.add_argument("-w", "--window", type=int, default=1000, help="Window size in bp")
    parser.add_argument("-p", "--prefix", required=True, help="Sample ID prefix")
    parser.add_argument("-o", "--outdir", default=".", help="Output directory")
    return parser.parse_args()

def calculate():
    args = parse_args()
    if not os.path.exists(args.outdir):
        os.makedirs(args.outdir)

    # Open VCF (pysam handles .vcf.gz and .tbi indexing automatically)
    vcf = pysam.VariantFile(args.vcf)
    chrom_lengths = {c.name: c.length for c in vcf.header.contigs.values()}
    
    data = []
    for rec in vcf:
        af_val = rec.info.get('AF', 0)
        af = af_val[0] if isinstance(af_val, (tuple, list)) else float(af_val)
        n = rec.info.get('DP', 1) 
        
        freqs = np.array([1-af, af])
        pi_b = (n / (n - 1)) * (1 - np.sum(freqs**2)) if n > 1 else 0
        active_freqs = freqs[freqs > 0]
        h_b = -np.sum(np.log(active_freqs) * active_freqs)
        
        data.append({'chrom': rec.chrom, 'window': rec.pos // args.window, 'pi_b': pi_b, 'h_b': h_b})

    # Build the skeleton
    all_windows = [
        {'chrom': chrom, 'window': w}
        for chrom, length in chrom_lengths.items()
        for w in range((length // args.window) + 1)
    ]
    
    skeleton = pd.DataFrame(all_windows)
    
    # Process and merge
    if data:
        df = pd.DataFrame(data)
        calculated = df.groupby(['chrom', 'window']).agg({
            'pi_b': 'mean', 
            'h_b': 'mean'
        }).reset_index()
        
        final_df = pd.merge(skeleton, calculated, on=['chrom', 'window'], how='left')
    else:
        final_df = skeleton.copy()
        final_df['pi_b'] = 0.0
        final_df['h_b'] = 0.0
        
    final_df[['pi_b', 'h_b']] = final_df[['pi_b', 'h_b']].fillna(0)
    
    # Define output filenames with window size
    w_size = f"{args.window}bp"
    pi_file = os.path.join(args.outdir, f"{args.prefix}_{w_size}_nucleotide_diversity.tsv")
    shannon_file = os.path.join(args.outdir, f"{args.prefix}_{w_size}_shannon_diversity.tsv")
    sum_file = os.path.join(args.outdir, f"{args.prefix}_{w_size}_summary.txt")
    
    # Save output
    final_df.to_csv(pi_file, sep='\t', index=False)
    final_df.to_csv(shannon_file, sep='\t', index=False)
    
    with open(sum_file, 'w') as f:
        f.write(f"Sample: {args.prefix}\n")
        f.write(f"Window Size: {args.window} bp\n")
        f.write(f"Genome-wide Pi_avg: {final_df['pi_b'].mean():.6f}\n")
        f.write(f"Genome-wide H_avg: {final_df['h_b'].mean():.6f}\n")

if __name__ == "__main__":
    calculate()
    
# #!/usr/bin/env python3
# import argparse
# import pandas as pd
# import numpy as np
# import pysam
# import os

# def parse_args():
#     parser = argparse.ArgumentParser(description="Calculate population diversity metrics.")
#     parser.add_argument("-v", "--vcf", required=True, help="Path to input VCF file")
#     parser.add_argument("-w", "--window", type=int, default=1000, help="Window size in bp")
#     parser.add_argument("-p", "--prefix", required=True, help="Sample ID prefix for output files")
#     parser.add_argument("-o", "--outdir", default=".", help="Output directory")
#     return parser.parse_args()

# def calculate():
#     args = parse_args()
#     if not os.path.exists(args.outdir):
#         os.makedirs(args.outdir)

#     data = []
#     vcf = pysam.VariantFile(args.vcf)
    
#     for rec in vcf:
#         af_val = rec.info.get('AF')
#         af = af_val[0] if isinstance(af_val, (tuple, list)) else float(af_val)
#         n = rec.info.get('DP', 1) 
        
#         freqs = np.array([1-af, af])
#         pi_b = (n / (n - 1)) * (1 - np.sum(freqs**2)) if n > 1 else 0
#         active_freqs = freqs[freqs > 0]
#         h_b = -np.sum(np.log(active_freqs) * active_freqs)
        
#         data.append({'chrom': rec.chrom, 'pos': rec.pos, 'pi_b': pi_b, 'h_b': h_b})
    
#     # Define file paths
#     pi_file = os.path.join(args.outdir, f"{args.prefix}_nucleotide_diversity.tsv")
#     shannon_file = os.path.join(args.outdir, f"{args.prefix}_shannon_diversity.tsv")
#     sum_file = os.path.join(args.outdir, f"{args.prefix}_summary.txt")

#     if not data:
#         # Create empty files with headers to satisfy Nextflow expectations
#         pd.DataFrame(columns=['chrom', 'window', 'pi_b']).to_csv(pi_file, sep='\t')
#         pd.DataFrame(columns=['chrom', 'window', 'h_b']).to_csv(shannon_file, sep='\t')
#         with open(sum_file, 'w') as f:
#             f.write(f"Sample: {args.prefix}\nNo variants found in VCF.\n")
#         return

#     df = pd.DataFrame(data)
#     df['window'] = df['pos'] // args.window
#     windowed = df.groupby(['chrom', 'window']).agg({'pi_b': 'mean', 'h_b': 'mean'})
    
#     # Save files
#     windowed[['pi_b']].to_csv(pi_file, sep='\t')
#     windowed[['h_b']].to_csv(shannon_file, sep='\t')
    
#     with open(sum_file, 'w') as f:
#         f.write(f"Sample: {args.prefix}\n")
#         f.write(f"Genome-wide Pi_avg: {df['pi_b'].mean():.6f}\n")
#         f.write(f"Genome-wide H_avg: {df['h_b'].mean():.6f}\n")
#         f.write(f"\nStats per segment/chromosome:\n")
#         f.write(df.groupby('chrom')[['pi_b', 'h_b']].mean().to_string())

# if __name__ == "__main__":
#     calculate()

