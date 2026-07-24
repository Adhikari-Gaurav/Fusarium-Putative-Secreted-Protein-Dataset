#! /usr/bin/env python3

import os
import glob
import sys
from Bio import SeqIO
from pathlib import Path
import argparse


def get_sample_names(target_dir):
    # Get the set of sample names by scanning subdirectories containing 'short_*.txt' in the target directory
    sample_paths = glob.glob(str(Path(target_dir) / "*/short_*.txt"))
    sample_names = [Path(sample_path).parts[-2] for sample_path in sample_paths]
    return sample_names


def check_seq_len(seq_file):
    # Return the length of the first sequence in the fasta file
    records = SeqIO.parse(seq_file, "fasta")
    for record in records:
        return len(record.seq)
    return 0


def get_IDs(seq_file):
    # Extract sequence IDs from fasta file and get sequence length
    seq_IDs = []
    with open(seq_file) as f:
        for line in f:
            if line.startswith(">"):
                seq_IDs.append(line.rstrip("\n").lstrip(">"))
    seq_len = check_seq_len(seq_file)
    return seq_len, seq_IDs


def fill_missing_samples(target_dir, fasta_dir, output_dir, max_missing_ratio):
    # Main logic to fill missing samples and write to output directory
    sample_names = get_sample_names(target_dir)
    n_samples = len(sample_names)
    seq_files = glob.glob(str(Path(fasta_dir) / "*_aln.clip.faa"))
    print(f"Found {len(seq_files)} fasta files to process.")
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    for idx, seq_file in enumerate(seq_files, 1):
        seq_len, seq_IDs = get_IDs(seq_file)
        miss_samples = set(sample_names) - set(seq_IDs)
        n_missing = len(miss_samples)
        missing_ratio = n_missing / n_samples if n_samples > 0 else 0
        if n_missing:
            print(
                f"[{idx}] {os.path.basename(seq_file)}: {n_missing} missing samples ({missing_ratio:.2%})."
            )
        else:
            print(f"[{idx}] {os.path.basename(seq_file)}: No missing samples.")
        # If missing ratio is too high, skip writing this file to output directory
        if missing_ratio > max_missing_ratio:
            print(
                f"  Skipped: missing ratio ({missing_ratio:.2%}) > max_missing_ratio ({max_missing_ratio:.2%})"
            )
            continue
        # If no missing samples, just copy the file to output
        if n_missing == 0:
            out_path = output_dir / os.path.basename(seq_file)
            with open(seq_file) as fin, open(out_path, "w") as fout:
                for line in fin:
                    fout.write(line)
            continue
        # Write original content and fill missing samples with gap sequences
        out_path = output_dir / os.path.basename(seq_file)
        with open(seq_file) as fin, open(out_path, "w") as fout:
            for line in fin:
                fout.write(line)
            for miss_sample in miss_samples:
                # Write missing sample header and gap sequence
                fout.write(f">{miss_sample}\n")
                fout.write(f"{seq_len * '-'}\n")


def main():
    # Parse command-line arguments and run the main function
    parser = argparse.ArgumentParser(description="Fill missing samples in fasta files.")
    parser.add_argument("target_dir", help="Target directory containing sample lists")
    parser.add_argument("fasta_dir", help="Directory containing fasta files")
    parser.add_argument("output_dir", help="Directory to write output fasta files")
    parser.add_argument(
        "--max-missing-ratio",
        "-r",
        type=float,
        default=1.0,
        help="Maximum ratio of missing samples to allow for filling (default: 1.0 = always fill)",
    )
    args = parser.parse_args()
    fill_missing_samples(
        args.target_dir, args.fasta_dir, args.output_dir, args.max_missing_ratio
    )


if __name__ == "__main__":
    main()
