#!/bin/bash
#SBATCH --partition tsl-medium   # adjust to match your cluster's partition names
#SBATCH -N 1 # number of nodes
#SBATCH -n 1 # Number of tasks
#SBATCH --cpus-per-task=16 # number of threads to run
#SBATCH --mem 256G # Memory Needed
#SBATCH -t 3-00:00 # time (D-HH:MM)
#SBATCH -o slurm.make_busco_fasta.%j.out # STDOUT
#SBATCH -e slurm.make_busco_fasta.%j.err # STDERR
#SBATCH -J make_busco_fasta

# -------------------------------------------------
# Activate BUSCO conda environment
# -------------------------------------------------
source ~/miniforge3/etc/profile.d/conda.sh
conda activate busco5

# -------------------------------------------------
# Set base directory and derived paths
# Override BASE_DIR when submitting the job, e.g.:
#   BASE_DIR=/path/to/your/project sbatch busco_pipeline.sh
# Everything else is relative to BASE_DIR so this script is portable
# across machines/clusters.
# -------------------------------------------------
BASE_DIR="${BASE_DIR:-$(pwd)}"
BUSCO_INPUT_DIR="${BASE_DIR}/busco_results"
BUSCO_FASTA_DIR="${BASE_DIR}/busco_seqs"
BUSCO_ALN_DIR="${BASE_DIR}/busco_seqs_aln"
BUSCO_FILLED_DIR="${BASE_DIR}/busco_seqs_aln_filled"
OUT_DIR="${BASE_DIR}/busco_supermatrix"
N_THREADS=16

# Delete existing directories if they exist
rm -rf "${BUSCO_FASTA_DIR}"
rm -rf "${BUSCO_ALN_DIR}"
rm -rf "${BUSCO_FILLED_DIR}"

# Prepare output directories
mkdir -p "${BUSCO_FASTA_DIR}"
mkdir -p "${BUSCO_ALN_DIR}"
mkdir -p "${BUSCO_FILLED_DIR}"

# Write BUSCO summary file
python3 ./00_get_busco_results.py "${BUSCO_INPUT_DIR}" > busco_summary.tsv

# Run BUSCO fasta extraction script
python3 ./extract_busco_fasta.py "${BUSCO_INPUT_DIR}" "${BUSCO_FASTA_DIR}" "${N_THREADS}"

# Function to run MAFFT and ClipKit
function run_mafft_clipkit () {
  PREFIX=$(basename "$1" .faa)
  ALN_OUT="${BUSCO_ALN_DIR}/${PREFIX}_aln.faa"
  CLIP_OUT="${BUSCO_ALN_DIR}/${PREFIX}_aln.clip.faa"
  # Run MAFFT alignment
  mafft "$1" > "${ALN_OUT}"
  # Run ClipKit on the alignment
  clipkit "${ALN_OUT}" -m gappy -g 0.9 -o "${CLIP_OUT}"
}

export -f run_mafft_clipkit
export BUSCO_ALN_DIR

# Run MAFFT and ClipKit in parallel
find "${BUSCO_FASTA_DIR}" -name "*.faa" | \
  xargs -P "${N_THREADS}" -I"%" bash -c "run_mafft_clipkit %"

# Fill missing samples (if needed)
MAX_MISSING_RATIO=0.1
python3 ./fill_missing_samples.py "${BUSCO_INPUT_DIR}" "${BUSCO_ALN_DIR}" "${BUSCO_FILLED_DIR}" --max-missing-ratio "${MAX_MISSING_RATIO}"

# Concatenate all alignments into a supermatrix
EXCLUDE_IDS="${OUT_DIR}/exclude_accessions.txt"

mkdir -p "${OUT_DIR}"

seqkit concat --full "${BUSCO_FILLED_DIR}"/*_aln.clip.faa > "${OUT_DIR}/busco_supermatrix.all.fasta"

# Remove excluded accessions from the final supermatrix, if an exclude file exists
if [[ -s "${EXCLUDE_IDS}" ]]; then
  seqkit grep -v -n -r -f "${EXCLUDE_IDS}" \
    "${OUT_DIR}/busco_supermatrix.all.fasta" > "${OUT_DIR}/busco_supermatrix.fasta"
else
  cp "${OUT_DIR}/busco_supermatrix.all.fasta" "${OUT_DIR}/busco_supermatrix.fasta"
fi

VeryFastTree -threads "${N_THREADS}" \
             "${OUT_DIR}/busco_supermatrix.fasta" > \
             "${OUT_DIR}/busco_supermatrix.tree"
