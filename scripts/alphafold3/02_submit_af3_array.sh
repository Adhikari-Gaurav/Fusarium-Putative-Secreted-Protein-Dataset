#!/bin/bash

# Usage: ./02_submit_af3_array.sh <input_json_dir> <output_dir>
INPUT=$1
OUTPUT=$2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sbatch \
  --array=0-$(($(find "$INPUT" -type f -iname "*.json" | wc -l)-1)) \
  "${SCRIPT_DIR}/03_af3_array_job.sh" "$INPUT" "$OUTPUT"
