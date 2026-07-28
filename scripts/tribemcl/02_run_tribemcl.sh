#!/bin/bash
#SBATCH --job-name=tribemcl_blast
#SBATCH --mem=128G
#SBATCH --cpus-per-task=20
#SBATCH --partition=tsl-long
#SBATCH --mail-type=BEGIN,END,FAIL
# #SBATCH --mail-user=you@example.com   # uncomment and set your own email for job notifications
#SBATCH --output=tribemcl_blast_%j.log
#SBATCH --error=tribemcl_blast_%j.err

set -euo pipefail

source ~/.bashrc
conda activate tribemcl
module load blast+/2.17.0

# BASE_DIR override: BASE_DIR=/path/to/your/project sbatch 02_run_tribemcl.sh
BASE_DIR="${BASE_DIR:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT_FASTA="${BASE_DIR}/combined_putative_secreted_proteins.fasta"
GET_TRIBES="${SCRIPT_DIR}/03_get_tribes.pl"
OUTPUT_DIR="${BASE_DIR}/tribemcl_putative_secreted"

mkdir -p "${OUTPUT_DIR}/logs"

echo "=== BLASTP + MCL clustering started: $(date) ==="
echo "Host: $(hostname)"
echo "Input FASTA: ${INPUT_FASTA}"
echo "Output directory: ${OUTPUT_DIR}"
echo "CPUs: ${SLURM_CPUS_PER_TASK}"

if [ ! -s "${INPUT_FASTA}" ]; then
    echo "ERROR: Input FASTA not found or empty: ${INPUT_FASTA}"
    exit 1
fi
if [ ! -s "${GET_TRIBES}" ]; then
    echo "ERROR: get_tribes.pl not found: ${GET_TRIBES}"
    exit 1
fi

echo "Protein count: $(grep -c '^>' "${INPUT_FASTA}")"
echo "BLAST version: $(blastp -version | head -1)"
echo "MCL version:"
mcl --version

cd "${OUTPUT_DIR}"

makeblastdb \
    -in "${INPUT_FASTA}" \
    -dbtype prot \
    -out putative_secreted_blastdb

blastp \
    -query "${INPUT_FASTA}" \
    -db putative_secreted_blastdb \
    -outfmt 7 \
    -out putative_secreted_blastp_self_e10.tsv \
    -evalue 1e-10 \
    -num_threads "${SLURM_CPUS_PER_TASK}"

mcxdeblast \
    --m9 \
    --line-mode=abc \
    --out=- \
    putative_secreted_blastp_self_e10.tsv | \
mcxload \
    -abc - \
    --stream-mirror \
    -write-tab putative_secreted_e10.tab \
    -o putative_secreted_e10.mci

mcl \
    putative_secreted_e10.mci \
    -use-tab putative_secreted_e10.tab \
    -I 1.4

MCL_OUT="out.putative_secreted_e10.mci.I14"
if [ ! -s "${MCL_OUT}" ]; then
    echo "ERROR: MCL output not found: ${MCL_OUT}"
    exit 1
fi

perl "${GET_TRIBES}" "${MCL_OUT}" > putative_secreted_e10_mcl.tribes

echo ""
echo "=== Results ==="
echo "BLAST output: ${OUTPUT_DIR}/putative_secreted_blastp_self_e10.tsv"
echo "MCL matrix: ${OUTPUT_DIR}/putative_secreted_e10.mci"
echo "MCL tab: ${OUTPUT_DIR}/putative_secreted_e10.tab"
echo "Raw MCL clusters: ${OUTPUT_DIR}/${MCL_OUT}"
echo "Tribe list: ${OUTPUT_DIR}/putative_secreted_e10_mcl.tribes"
echo "Clusters found: $(wc -l < "${MCL_OUT}")"
echo "Largest cluster size: $(awk '{print NF}' "${MCL_OUT}" | sort -nr | head -1)"
echo "=== Completed: $(date) ==="
