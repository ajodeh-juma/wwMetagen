#!/usr/bin/env python3

"""
merge reads from NEXTSEQ (550) or generate manifest (2K, MISEQ)
"""

import os
import re
import sys
import logging
import argparse
import csv
from utils import run_shell_command

logging.basicConfig(level=logging.INFO, 
                    format='[%(asctime)s] - %(levelname)s - %(message)s',
                    datefmt='%Y-%m-%d %I:%M:%S %p')

def parse_args():
    parser = argparse.ArgumentParser(description="Merge or manifest sequencing reads.")
    required = parser.add_argument_group('required arguments')
    required.add_argument('--data-dir', required=True, help="Path to rawdata")
    parser.add_argument('--out-dir', default=".", help="Output directory")
    # Added 'miseq' option
    parser.add_argument('--machine', choices=['550', '2K', 'miseq'], default='550')
    parser.add_argument('--prefix', default="", help="Filename for the manifest CSV")
    return parser.parse_args()

def traverse_dir(data_dir, machine):
    valid_ext = ('.fastq', '.fastq.gz', '.fq', '.fq.gz')
    samples_dict = {}
    
    logging.info(f"Traversing directory: {os.path.abspath(data_dir)}")
    
    for root, _, filenames in os.walk(data_dir):
        for filename in filenames:
            if not filename.lower().endswith(valid_ext):
                continue
            
            base_name = re.sub(r'\.(fastq|fq)(\.gz)?$', '', filename)
            # Basic identification
            sample_id = re.split(r'_S\d+_R[12]', base_name)[0]
            sample_id = sample_id.replace(".", "_").replace(" ", "_")

            if ".fail" in base_name or 'Undetermined' in base_name or base_name.startswith("."):
                continue

            sample_id = re.sub(r'(_[rR][12])', '', sample_id)
                
            # Adjusted regex patterns
            if machine == '550':
                sample_id = re.sub('_S([0-9]+)_L[0-9]{3}_[0-9]{3}', '', sample_id)
            elif machine == '2K':
                # sample_id = re.sub('_S([0-9]+)_[0-9]{3}', '', sample_id)

                # this pattern is hardcoded to work for smaples already concatenated
                sample_id = re.sub('_S([0-9]+)(_con)?_[0-9]{3}', '', sample_id)

            elif machine == 'miseq':
                sample_id = re.sub('_S([0-9]+)_L[0-9]{3}_[0-9]{3}', '', sample_id)
            
            samples_dict.setdefault(sample_id, []).append(os.path.join(root, filename))
            
    return samples_dict

def print_summary(samples_dict):
    print(f"\n{'='*60}")
    print(f"{'IDENTIFIED ' + str(len(samples_dict)) + ' UNIQUE SAMPLES':^60}")
    print(f"{'='*60}")
    print(f"{'Sample ID':<40} | {'Files Found':>10}")
    print(f"{'-'*60}")
    for sample, reads in sorted(samples_dict.items()):
        print(f"{sample:<40} | {len(reads):>10}")
    print(f"{'='*60}\n")

def cat_fastq(reads, output):
    reads.sort()
    cmd = f"cat {' '.join(reads)} > {output}"
    logging.info(f"Concatenating into {output}")
    run_shell_command(cmd, raise_errors=True)

def main():
    args = parse_args()
    if not os.path.isdir(args.data_dir):
        logging.error(f"Directory not found: {args.data_dir}")
        sys.exit(1)
        
    os.makedirs(args.out_dir, exist_ok=True)
    d = traverse_dir(args.data_dir, args.machine)
    
    print_summary(d)

    # Only perform concatenation for 550
    if args.machine == '550':
        for sample_id, reads in d.items():
            r1_out = os.path.join(args.out_dir, f"{sample_id}_R1.fastq.gz")
            r2_out = os.path.join(args.out_dir, f"{sample_id}_R2.fastq.gz")
            
            if os.path.exists(r1_out) and os.path.exists(r2_out):
                logging.info(f"Concatenated files exist for {sample_id}. Skipping.")
            else:
                r1 = [f for f in reads if "_R1" in f]
                r2 = [f for f in reads if "_R2" in f]
                if r1: cat_fastq(r1, r1_out)
                if r2: cat_fastq(r2, r2_out)
        
        # Re-traverse to update manifest with new files
        d = traverse_dir(args.out_dir, args.machine)

    # Generate manifest for 2K, MiSeq, or already merged 550s
    csv_filename = f"{args.prefix}.csv" if args.prefix else "sample_manifest.csv"
    csv_file = os.path.join(args.out_dir, csv_filename)
    
    logging.info(f"Generating manifest: {csv_file}")
    with open(csv_file, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(["sample", "fastq_1", "fastq_2"])
        for sample, files in sorted(d.items()):
            r1 = [f for f in files if "_R1" in f]
            r2 = [f for f in files if "_R2" in f]
            writer.writerow([sample, ";".join(r1), ";".join(r2)])

if __name__ == '__main__':
    main()


# #!/usr/bin/env python3

# """
# merge reads from NEXTSEQ output run (550) or generate manifest (2K)
# """

# import os
# import re
# import sys
# import logging
# import argparse
# import csv
# from utils import run_shell_command

# logging.basicConfig(level=logging.INFO, 
#                     format='[%(asctime)s] - %(levelname)s - %(message)s',
#                     datefmt='%Y-%m-%d %I:%M:%S %p')

# def parse_args():
#     parser = argparse.ArgumentParser(description="Merge or manifest NextSeq reads.")
#     required = parser.add_argument_group('required arguments')
#     required.add_argument('--data-dir', required=True, help="Path to rawdata")
#     parser.add_argument('--out-dir', default=".", help="Output directory")
#     parser.add_argument('--machine', choices=['550', '2K'], default='550')
#     parser.add_argument('--prefix', default="", help="Filename for the manifest CSV (e.g., my_samples)")
#     return parser.parse_args()

# def traverse_dir(data_dir, machine):
#     valid_ext = ('.fastq', '.fastq.gz', '.fq', '.fq.gz')
#     samples_dict = {}
    
#     logging.info(f"Traversing directory: {os.path.abspath(data_dir)}")
    
#     for root, _, filenames in os.walk(data_dir):
#         for filename in filenames:
#             if not filename.lower().endswith(valid_ext):
#                 continue
            
#             # Extract sample_id based on your specified logic
#             base_name = re.sub(r'\.(fastq|fq)(\.gz)?$', '', filename)
#             sample_id = re.split(r'_S\d+_R[12]', base_name)[0]
#             sample_id = sample_id.replace(".", "_").replace(" ", "_")

#             if ".fail" in base_name or 'Undetermined' in base_name or base_name.startswith("."):
#                 continue

#             sample_id = re.sub(r'(_[rR][12])', '', sample_id)
                
#             if machine == '550':
#                 sample_id = re.sub('_S([0-9]+)_L[0-9]{3}_[0-9]{3}', '', sample_id)
#             elif machine == '2K':
#                 sample_id = re.sub('_S([0-9]+)_[0-9]{3}', '', sample_id)

#                 # this pattern is hardcoded to work for smaples already concatenated
#                 # sample_id = re.sub('_S([0-9]+)(_con)?_[0-9]{3}', '', sample_id)
            
#             samples_dict.setdefault(sample_id, []).append(os.path.join(root, filename))
            
#     return samples_dict

# def print_summary(samples_dict):
#     print(f"\n{'='*60}")
#     print(f"{'IDENTIFIED ' + str(len(samples_dict)) + ' UNIQUE SAMPLES':^60}")
#     print(f"{'='*60}")
#     print(f"{'Sample ID':<40} | {'Files Found':>10}")
#     print(f"{'-'*60}")
#     for sample, reads in sorted(samples_dict.items()):
#         print(f"{sample:<40} | {len(reads):>10}")
#     print(f"{'='*60}\n")

# def cat_fastq(reads, output):
#     reads.sort()
#     cmd = f"cat {' '.join(reads)} > {output}"
#     logging.info(f"Concatenating into {output}")
#     run_shell_command(cmd, raise_errors=True)

# def main():
#     args = parse_args()
#     if not os.path.isdir(args.data_dir):
#         logging.error(f"Directory not found: {args.data_dir}")
#         sys.exit(1)
        
#     os.makedirs(args.out_dir, exist_ok=True)
#     d = traverse_dir(args.data_dir, args.machine)
    
#     # Print summary of identified samples
#     print_summary(d)

#     # 550 Concatenation logic with idempotency check
#     if args.machine == '550':
#         for sample_id, reads in d.items():
#             r1_out = os.path.join(args.out_dir, f"{sample_id}_R1.fastq.gz")
#             r2_out = os.path.join(args.out_dir, f"{sample_id}_R2.fastq.gz")
            
#             if os.path.exists(r1_out) and os.path.exists(r2_out):
#                 logging.info(f"Concatenated files exist for {sample_id}. Skipping.")
#             else:
#                 r1 = [f for f in reads if "_R1" in f]
#                 r2 = [f for f in reads if "_R2" in f]
#                 if r1: cat_fastq(r1, r1_out)
#                 if r2: cat_fastq(r2, r2_out)
        
#         # Re-traverse the output directory for manifest accuracy
#         d = traverse_dir(args.out_dir, args.machine)

#     # Generate manifest CSV
#     csv_filename = f"{args.prefix}.csv" if args.prefix else "sample_manifest.csv"
#     csv_file = os.path.join(args.out_dir, csv_filename)
    
#     logging.info(f"Generating manifest: {csv_file}")
#     with open(csv_file, 'w', newline='') as f:
#         writer = csv.writer(f)
#         writer.writerow(["sample", "fastq_1", "fastq_2"])
#         for sample, files in sorted(d.items()):
#             r1 = [f for f in files if "_R1" in f]
#             r2 = [f for f in files if "_R2" in f]
#             writer.writerow([sample, ";".join(r1), ";".join(r2)])

# if __name__ == '__main__':
#     main()