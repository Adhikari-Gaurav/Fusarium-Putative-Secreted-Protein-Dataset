#!/bin/bash

#SBATCH --job-name=AF3_array
#SBATCH -o slurm.%j.out
#SBATCH -e slurm.%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
# #SBATCH --mail-user=you@example.com   # uncomment and set your own email for job notifications
#SBATCH --array=0-0   # will be overridden dynamically
#SBATCH --partition=tsl-gpu
#SBATCH -c 8
#SBATCH --gres=gpu:1
#SBATCH --mem=120G

# -----------------------------
# Check input arguments
# -----------------------------
if [ -z "$1" ]; then
    echo "ERROR: You must provide the input directory containing JSON files."
    exit 1
fi

if [ -z "$2" ]; then
    echo "ERROR: You must provide an output directory."
    exit 1
fi

# -----------------------------
# AlphaFold 3 install/database locations (override via environment)
# -----------------------------
AF3_BIN="${AF3_BIN:-/tsl/software/testing/alphafold/3.0.2/x86_64/bin/run_alphafold.py}"
AF3_MODEL_DIR="${AF3_MODEL_DIR:-/tsl/industry/bioinformatics/af3weights}"
AF3_DB_DIR="${AF3_DB_DIR:-/nbi/Reference-Data/AlphaFold/db-v3.0.0}"
AF3_SMALL_BFD_DB="${AF3_SMALL_BFD_DB:-/nbi/Reference-Data/AlphaFold/db-v2.3.2/small_bfd/bfd-first_non_consensus_sequences.fasta}"
AF3_MGNIFY_DB="${AF3_MGNIFY_DB:-/nbi/Reference-Data/AlphaFold/db-v2.3.2/mgnify/mgy_clusters_2022_05.fa}"

# -----------------------------
# Collect all JSON files
# -----------------------------
JSON_FILES=($(find "$1" -type f -iname "*.json" | sort))

if [ ${#JSON_FILES[@]} -eq 0 ]; then
    echo "ERROR: No JSON files found in $1"
    exit 1
fi

# -----------------------------
# Select JSON file for this array task
# -----------------------------
TARGET_JSON=${JSON_FILES[$SLURM_ARRAY_TASK_ID]}

echo "Task $SLURM_ARRAY_TASK_ID: Running AlphaFold on $TARGET_JSON"

# -----------------------------
# Run AlphaFold
# -----------------------------
"${AF3_BIN}" --json_path="$TARGET_JSON" \
    --model_dir="${AF3_MODEL_DIR}" \
    --db_dir="${AF3_DB_DIR}" \
    --small_bfd_database_path="${AF3_SMALL_BFD_DB}" \
    --mgnify_database_path="${AF3_MGNIFY_DB}" \
    --output_dir="${2}"

AF3_EXIT=$?

# -----------------------------
# Compress this task's output (.gz)
# -----------------------------
if [ $AF3_EXIT -ne 0 ]; then
    echo "AlphaFold exited with code $AF3_EXIT for $TARGET_JSON — skipping compression."
    exit $AF3_EXIT
fi

# Fixed: JSON is an array so index [0] to get name field
SUBDIR=$(python3 -c '
import json, string, sys
name = json.load(open(sys.argv[1]))[0]["name"]
allowed = set(string.ascii_lowercase + string.ascii_uppercase + string.digits + "_-.")
s = name.replace(" ", "_")
print("".join(c for c in s if c in allowed))
' "$TARGET_JSON")

TASK_OUT="${2}/${SUBDIR}"

if [ ! -d "$TASK_OUT" ]; then
    echo "WARNING: expected output dir '$TASK_OUT' not found — skipping compression."
    exit 0
fi

echo "Compressing output in $TASK_OUT"

if command -v pigz >/dev/null 2>&1; then
    pigz -p "${SLURM_CPUS_PER_TASK:-8}" -r "$TASK_OUT"
else
    gzip -r "$TASK_OUT"
fi

echo "Done: compressed $TASK_OUT"
