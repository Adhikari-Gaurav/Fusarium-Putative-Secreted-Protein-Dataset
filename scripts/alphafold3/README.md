# AlphaFold 3 structure prediction

This stage takes the putative secreted protein candidates that have been trimmed and clustered into tribes in the previous stage and predicts their 3D structures using AlphaFold 3. Each candidate sequence is packaged into an AlphaFold 3 input JSON file, and structure prediction jobs are then submitted to the cluster as a SLURM job array so that many sequences can be folded in parallel.

## 1. Generate AlphaFold 3 input JSON files

Script: [`01_generate_af3_json.py`](01_generate_af3_json.py)

Reads a FASTA file of protein (or nucleic acid) sequences and writes one AlphaFold 3 input JSON per sequence (or a single combined JSON, if requested). For each sequence, the script auto-detects whether it is protein, DNA, or RNA and builds the corresponding `proteinChain`/`dnaChain`/`rnaChain` entry, with an optional ligand entry and one or more model seeds.

Usage:

```bash
python3 01_generate_af3_json.py --fasta combined_putative_secreted_proteins.fasta --output-dir af3_input
```

Useful options:

- `--seq-copies N` — number of copies of each sequence in the complex (default: 1)
- `--ligand LIGAND` / `--ligand-copies N` — include a ligand alongside each sequence
- `--seeds N [N ...]` — one or more model seeds; a separate job JSON is written per seed if more than one is given
- `--suffix TEXT` — appended to generated job names
- `--use-structure-template` — sets `useStructureTemplate: true` on protein chains
- `--max-template-date DATE` — sets `maxTemplateDate` on protein chains (e.g. `2025-02-03`)
- `--single-json FILE` — write all generated jobs into one combined JSON file instead of one file per job

By default, one JSON file is written per job into `--output-dir`; these are the files consumed by step 2 below.

## 2. Submit the AlphaFold 3 job array

Script: [`02_submit_af3_array.sh`](02_submit_af3_array.sh)

Counts the JSON files in the given input directory and submits `03_af3_array_job.sh` as a SLURM array job sized to match, so that each array task processes exactly one JSON file.

Usage:

```bash
./02_submit_af3_array.sh <input_json_dir> <output_dir>
```

`<input_json_dir>` is the `--output-dir` used in step 1, and `<output_dir>` is where AlphaFold 3's predicted structures will be written.

## 3. Per-task AlphaFold 3 worker (runs automatically)

Script: [`03_af3_array_job.sh`](03_af3_array_job.sh)

This script is submitted automatically by step 2 and does not need to be run directly. Each array task picks the JSON file corresponding to its `SLURM_ARRAY_TASK_ID`, runs `run_alphafold.py` against it, and — on success — compresses its output subfolder with `pigz` (falling back to `gzip` if `pigz` is unavailable) to save disk space.

The AlphaFold 3 binary and database locations are read from environment variables, each with a default matching the original cluster installation used for this project. Override them if your installation differs:

```bash
AF3_BIN=/path/to/run_alphafold.py \
AF3_MODEL_DIR=/path/to/af3weights \
AF3_DB_DIR=/path/to/alphafold/db \
AF3_SMALL_BFD_DB=/path/to/small_bfd.fasta \
AF3_MGNIFY_DB=/path/to/mgnify.fa \
./02_submit_af3_array.sh <input_json_dir> <output_dir>
```

The script also expects a GPU partition (`--gres=gpu:1`) and substantial memory (120G); adjust the `#SBATCH` directives at the top of the script to match your cluster's resources and partition names.

## Citation

If you use AlphaFold 3, please cite:

Abramson J, Adler J, Dunger J, Evans R, Green T, Pritzel A, et al. Accurate structure prediction of biomolecular interactions with AlphaFold 3. Nature. 2024;630(8016):493-500. DOI: [10.1038/s41586-024-07487-w](https://doi.org/10.1038/s41586-024-07487-w).
