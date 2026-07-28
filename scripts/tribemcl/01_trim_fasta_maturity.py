#!/usr/bin/env python3
import os
import re

# BASE_DIR override: BASE_DIR=/path/to/your/project python3 01_trim_fasta_maturity.py
BASE_DIR = os.environ.get("BASE_DIR", os.getcwd())

input_fasta = os.path.join(BASE_DIR, "combined_filtered.fasta")
output_fasta = os.path.join(BASE_DIR, "combined_filtered_trimmed_matured.fasta")

def write_fasta(out, header, seq):
    match = re.search(r"NNCleavageSite=(\d+)", header)
    if not match:
        return
    cut = int(match.group(1))
    trimmed = seq[cut:]
    out.write(header + "\n")
    for i in range(0, len(trimmed), 60):
        out.write(trimmed[i:i+60] + "\n")

with open(input_fasta) as infile, open(output_fasta, "w") as out:
    header = None
    seq_parts = []
    for line in infile:
        line = line.rstrip()
        if line.startswith(">"):
            if header is not None:
                write_fasta(out, header, "".join(seq_parts))
            header = line
            seq_parts = []
        else:
            seq_parts.append(line)
    if header is not None:
        write_fasta(out, header, "".join(seq_parts))
