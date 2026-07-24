#! /usr/bin/env python3

import os
import glob
import sys
import re
import json


input_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
input_files = glob.glob(os.path.join(input_dir, '*/short_summary.*.json'))
input_files = sorted(input_files)

print("Assembly Accession", "BUSCO database", "BUSCO result", "Complete BUSCOs (C)", "Complete and single-copy BUSCOs (S)", "Complete and duplicated BUSCOs (D)", "Fragmented BUSCOs (F)", "Missing BUSCOs (M)", "Total BUSCO groups searched", sep="\t")

for input_file in input_files:
    with open(input_file, 'r') as jf:
        data = json.load(jf)
    # Extract accession from parameters["in"]
    acc = ""
    if "parameters" in data and "in" in data["parameters"]:
        m = re.search(r'(GCA_\d+\.\d+|GCF_\d+\.\d+)', data["parameters"]["in"])
        if m:
            acc = m.group(1)
    busco_db = data.get("lineage_dataset", {}).get("name", "")
    result_line = data.get("results", {}).get("one_line_summary", "")
    # Parse percentages from one_line_summary
    busco_scores = [s.split("%") [0] for s in result_line.split(":")[1:]] if result_line else [""]*6
    print(acc, busco_db, result_line, "\t".join(busco_scores), sep="\t")
