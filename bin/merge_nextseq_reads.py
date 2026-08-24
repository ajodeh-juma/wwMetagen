#!/usr/bin/env python3

"""
merge reads from NEXTSEQ output run i.e merge reads from the same sample but on different lanes
L001, L002, L003, L004
"""

# --- standard python imports ---#
import os
import re
import sys
import logging
import argparse
import textwrap

# from utils import dir_path
from utils import run_shell_command

log_level = logging.DEBUG
logging.basicConfig(level=log_level,
                    format='[%(asctime)s] - %(''levelname)s - [%(funcName)s] - %(message)s',
                    datefmt='%Y-%m-%d %I:%M:%S %p'
                    )


def parse_args():
    """
    command line arguments

    :return:
    """
    parser = argparse.ArgumentParser(prog="merge_nextseq_reads.py",
                                     formatter_class=argparse.ArgumentDefaultsHelpFormatter,
                                     description=textwrap.dedent('''\
                                        -----------merge reads from NEXTSEQ output run-------------
    
                                        '''),
                                     argument_default=argparse.SUPPRESS)
    required_group = parser.add_argument_group('required arguments')

    required_group.add_argument('--data-dir', type=str, metavar='<DIR>', dest="data_dir",
                                help="path to the rawdata directory"
                                )
    required_group.add_argument('--out-dir', type=str, metavar='<DIR>', dest="out_dir", default=".",
                                help="path to the output data directory"
                                )
    required_group.add_argument('--machine', type=str, metavar='<string>', dest="machine", default="550", choices=['550', '2K'],
                                help="Nextseq machine type, either 550 or 2K"
                                )
    parser.add_argument('-v', '--verbose',
                        action='count',
                        default=0,
                        dest="verbose",
                        help="verbose output (repeat for increased verbosity)"
                        )
    parser.add_argument('-q', '--quiet',
                        action='count',
                        default=0,
                        dest='quiet',
                        help="quiet output (show errors only)"
                        )
    return parser


def traverse_dir(data_dir, machine):
    """

    :param data_dir:
    :return:
    """

    ext = "fastq fq".split()
    samples_dict = dict()
    logging.info("traversing through the directory: {}".format(os.path.abspath(data_dir)))
    for root, dirs, filenames in os.walk(data_dir):
        filenames.sort()
        for filename in filenames:
            if ext[0] in filename or ext[1] in filename:
                sample_id = filename.split('.fastq')[0].split('.fq')[0]
                if ".fail" in sample_id or 'Undetermined' in sample_id or sample_id.startswith("."):
                    continue
                else:
                    if sample_id.startswith("_"):
                        sample_id = sample_id.split("_", 1)[1]
                sample_id = sample_id.replace("_R1", "").replace("_r1", "").replace("_R2", "").replace("_r2", "")
                sample_id = sample_id.replace('.R1', '_R1').replace('.R2', '_R2').replace("_R1", "").replace("_R2", "")
                
                if machine == '550':
                    sample_id = re.sub('_S([0-9]+)_L[0-9]{3}_[0-9]{3}', '', sample_id)
                if machine == '2K':
                    sample_id = re.sub('_S([0-9]+)_[0-9]{3}', '', sample_id)

                sample_id = sample_id.replace("_", "-").replace(" ", "-")
                filepath = os.path.join(root, filename)

                if not sample_id in samples_dict:
                    samples_dict[sample_id] = [filepath]
                else:
                    samples_dict[sample_id].append(filepath)
    print("\n{:<30}\t{:>20}".format("Sample", "Files"))
    for sample, reads in samples_dict.items():
        print("{:<30}\t{:>20}\n".format(sample, '\n\t\t\t\t'.join(reads)))
    return samples_dict


def cat_fastq(reads, output):
    """

    """
    output = os.path.abspath(output)
    call = ["cat {} > {}".format(reads, output)]
    cmd = "".join(call)
    print(cmd)
    logging.info("concatenating reads: {} into {}".format(reads, output))
    run_shell_command(cmd, raise_errors=False, extra_env=None)
    return output


def main():
    parser = parse_args()
    args = parser.parse_args()
    if not os.path.isdir(args.data_dir):
        print("not a directory {}".format(args.data_dir))
        sys.exit(1)
    else:
        dd = args.data_dir

    if not os.path.exists(os.path.abspath(args.out_dir)):
        os.makedirs(os.path.abspath(args.out_dir))

    d = traverse_dir(data_dir=dd, machine=args.machine)

    # iterate through the dict
    for sample_id, reads in d.items():
        reads1 = " ".join([reads[i] for i in range(len(reads)) if i in [0, 2, 4, 6]])
        reads2 = " ".join([reads[i] for i in range(len(reads)) if i in [1, 3, 5, 7]])
        f = os.path.join(args.out_dir, sample_id + '_R1.fastq.gz')
        r = os.path.join(args.out_dir, sample_id + '_R2.fastq.gz')
        cat_fastq(reads1, f)
        cat_fastq(reads2, r)


if __name__ == '__main__':
    main()
