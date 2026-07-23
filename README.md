# Fusarium-Effector-Dataset---Effectoromics

Effector dataset and analysis scripts for Fusarium effectoromics research.

## Overview

This repository collects the scripts and data used for identifying and characterizing candidate effector proteins in Fusarium genomes.

## Repository contents

The repository includes scripts for downloading accessions via NCBI command-line tools, analysis scripts for effector prediction and characterization, and supporting data files.

## Pipeline steps

1. [Data acquisition](#1-data-acquisition)
   1. [Set up an isolated environment](#11-set-up-an-isolated-environment)
   2. [Activate the environment](#12-activate-the-environment)
   3. [Install the NCBI Datasets CLI](#13-install-the-ncbi-datasets-cli)
   4. [Prepare the accession list](#14-prepare-the-accession-list)
   5. [Download the genomes in dehydrated form](#15-download-the-genomes-in-dehydrated-form)
   6. [Unzip the downloaded package](#16-unzip-the-downloaded-package)
   7. [Rehydrate the dataset](#17-rehydrate-the-dataset)
2. [BUSCO analysis](#2-busco-analysis)
   1. [Summarize BUSCO scores](#21-summarize-busco-scores)
   2. [Extract single-copy ortholog sequences](#22-extract-single-copy-ortholog-sequences)
   3. [Align and trim each ortholog](#23-align-and-trim-each-ortholog)
   4. [Fill in missing samples](#24-fill-in-missing-samples)
   5. [Concatenate into a supermatrix](#25-concatenate-into-a-supermatrix)
   6. [Build the phylogenetic tree](#26-build-the-phylogenetic-tree)
3. [Helixer annotation](#3-helixer-annotation)
4. [SignalP 2](#4-signalp-2)
5. [Predector](#5-predector)
6. [Sequence clustering (TRIBE-MCL)](#6-sequence-clustering-tribe-mcl)
7. [AlphaFold 3](#7-alphafold-3)

## 1. Data acquisition

Genome assemblies for this project are pulled directly from NCBI using their official Datasets command-line tool, `datasets`. Below is a walkthrough of the full process, step by step, from installing the tool to ending up with usable genome files on disk.

This was run using `ncbi-datasets-cli` v18.25.0 on Python 3.11; see [`environment.yml`](environment.yml) at the root of this repo for the exact pinned versions if you want to reproduce it precisely.

### 1.1 Set up an isolated environment

Before installing anything, it's good practice to create a dedicated conda environment rather than installing packages into your base environment. A conda environment is essentially a self-contained sandbox: it keeps a project's tools and their exact versions separate from everything else on your system, so that different projects, or different versions of the same tool, don't end up interfering with one another later on.

```
conda create -n ncbi_datasets
```

This creates a new, empty environment named `ncbi_datasets`. At this point it has no packages in it yet; it's just a clean, reserved space for this project's dependencies.

### 1.2 Activate the environment

Once the environment exists, it needs to be activated so that anything installed afterward lands inside it instead of in the base environment:

```
conda activate ncbi_datasets
```

Your terminal prompt will typically change to show the environment's name in parentheses, which is a quick visual confirmation that you're now working inside `ncbi_datasets` rather than the system default.

### 1.3 Install the NCBI Datasets CLI

With the environment active, the actual tools can be installed from the conda-forge channel:

```
conda install -c conda-forge ncbi-datasets-cli
```

This single package brings in two command-line programs: `datasets`, which is used to search for and download genome, gene, and taxonomy data, and `dataformat`, which is used to convert the metadata NCBI returns into more readable, tabular formats.

### 1.4 Prepare the accession list

Downloading is driven by a plain text file, conventionally named `accessions.txt`, that simply lists the genomes you want, one NCBI assembly accession per line, for example `GCA_000149555.1`. There's nothing more complicated to it than that: it's essentially a shopping list that tells the `datasets` tool exactly which genomes to go and fetch, so you don't have to type each accession out by hand on the command line.

Use the full versioned accession (`GCA_000149555.1`, not the bare `GCA_000149555`); both GCA (GenBank) and GCF (RefSeq) accessions are accepted.

### 1.5 Download the genomes in dehydrated form

With the environment active and the accession list ready, the genomes are downloaded using the `--dehydrated` flag. This pipeline only needs the genomic sequence, not NCBI's own GFF, protein, or RNA files, so the download is restricted to genome FASTA with `--include genome`:

```
datasets download genome accession --inputfile accessions.txt --dehydrated --include genome
```

Restricting to `--include genome` matters at scale: by default `datasets download genome` pulls the full data package (genome, GFF, protein, RNA, and report files) for every accession, which adds up to a lot of unused disk space across a large accession list when all you actually need downstream is the genomic sequence.

For accession lists this size, it's also worth setting an NCBI API key to avoid rate-limit throttling on unauthenticated requests, either by adding `--api-key <your-api-key>` to the command above or by exporting it once as the `NCBI_API_KEY` environment variable so it doesn't need to be passed every time.

### 1.6 Unzip the downloaded package

The command above produces a zip archive (`ncbi_dataset.zip`) containing the metadata and manifest. It needs to be extracted before it can be rehydrated:

```
unzip ncbi_dataset.zip -d genomes
```

This unpacks everything into a folder named `genomes`. After rehydration (next step), the genomic FASTA for each accession lands at `genomes/ncbi_dataset/data/<accession>/<accession>_*_genomic.fna`, useful to know so downstream steps like BUSCO can glob for it directly rather than guessing the path.

### 1.7 Rehydrate the dataset

The final step actually retrieves the real sequence files referenced in the manifest:

```
datasets rehydrate --directory genomes
```

Rehydrating reads the manifest inside the `genomes` folder and downloads the full genome sequence files to match it. Splitting the process into dehydrate-then-rehydrate steps means the heavy part of the download (the actual sequence data) only happens once you're sure you want it, rather than upfront for every accession in the list.

## 2. BUSCO analysis

Once genomes are on disk, each assembly is run through BUSCO separately (one BUSCO run per genome, against whichever lineage dataset is appropriate) to assess completeness and, more importantly for this project, to pull out single-copy orthologous genes shared across all the assemblies. The scripts in this section pick up after that per-genome BUSCO run has already been done, and take care of everything from there: summarizing the scores, extracting the shared single-copy genes, aligning and trimming them, patching any samples missing from a given gene, concatenating everything into one supermatrix, and building a tree from it.

The scripts live in [`scripts/busco/`](scripts/busco/), and `busco_pipeline.sh` is the SLURM batch script that runs the whole thing end to end on an HPC cluster (adjust the `#SBATCH` partition and resource requests for your own cluster). It expects a `BASE_DIR` pointing at a working directory containing a `busco_results` folder with all the individual per-genome BUSCO output subdirectories inside it, and writes everything else relative to that:

```
BASE_DIR=/path/to/your/project sbatch scripts/busco/busco_pipeline.sh
```

The subsections below walk through what each part of that script actually does.

### 2.1 Summarize BUSCO scores

The first thing the pipeline does is collect a one-line completeness summary (Complete, Fragmented, Missing, etc.) for every genome into a single table, using [`00_get_busco_results.py`](scripts/busco/00_get_busco_results.py):

```
python3 00_get_busco_results.py busco_results > busco_summary.tsv
```

It scans each per-genome BUSCO output folder for its `short_summary.*.json` file, pulls out the assembly accession, the lineage database used, and the C/S/D/F/M scores, and writes it all out as a TSV. This is mainly a sanity check: a quick way to scan for any genome with an unexpectedly low completeness score before spending time on the rest of the pipeline.

### 2.2 Extract single-copy ortholog sequences

Next, [`extract_busco_fasta.py`](scripts/busco/extract_busco_fasta.py) gathers the single-copy BUSCO genes that BUSCO already identified for each genome individually, and regroups them by gene instead of by genome. In other words: instead of "genome A's copy of every gene," you end up with "every genome's copy of gene X," one FASTA file per BUSCO gene, which is the layout needed for the alignment step next.

```
python3 extract_busco_fasta.py busco_results busco_seqs 16
```

The three arguments are the directory containing the per-genome BUSCO results, the output directory for the per-gene FASTA files, and the number of parallel worker threads to use (there can be hundreds of BUSCO genes to process, so this step is parallelized). Each sequence's FASTA header is renamed to the genome's sample name rather than BUSCO's internal gene ID, since that's what's needed to keep track of which sequence belongs to which genome once everything is later concatenated.

### 2.3 Align and trim each ortholog

Each per-gene FASTA file (one sequence per genome) is then aligned with MAFFT and trimmed with ClipKit, run in parallel across genes:

```
mafft gene.faa > gene_aln.faa
clipkit gene_aln.faa -m gappy -g 0.9 -o gene_aln.clip.faa
```

MAFFT produces the multiple sequence alignment; ClipKit then removes poorly aligned, gap-heavy columns from it (`-m gappy -g 0.9` trims columns that are more than 90% gaps), which helps keep noisy alignment regions out of the eventual supermatrix and tree.

### 2.4 Fill in missing samples

Not every genome necessarily has a hit for every single BUSCO gene, so [`fill_missing_samples.py`](scripts/busco/fill_missing_samples.py) checks each trimmed alignment against the full list of genomes and patches in gap-only sequences for any that are missing:

```
python3 fill_missing_samples.py busco_results busco_seqs_aln busco_seqs_aln_filled --max-missing-ratio 0.1
```

This matters because concatenating alignments into a supermatrix requires every gene alignment to have a row for every genome; without this step, a gene missing from even one genome couldn't be concatenated at all. If a given gene is missing from too many genomes, though, filling it in with gaps stops being useful information and starts diluting the supermatrix, so the `--max-missing-ratio` flag (here set to 0.1, i.e. 10%) drops any gene alignment that's missing more genomes than that threshold instead of filling it.

### 2.5 Concatenate into a supermatrix

All of the filled, trimmed per-gene alignments are then concatenated end to end into one supermatrix, using `seqkit concat`:

```
seqkit concat --full busco_seqs_aln_filled/*_aln.clip.faa > busco_supermatrix.all.fasta
```

If there's a reason to drop specific genomes from the final tree (contamination, misidentification, etc.), their accessions can be listed one per line in an `exclude_accessions.txt` file placed in the output directory; the pipeline checks for that file and, if present, removes those accessions from the supermatrix before moving on. If no such file exists, the full supermatrix is used as-is.

### 2.6 Build the phylogenetic tree

Finally, VeryFastTree builds a maximum-likelihood tree from the supermatrix:

```
VeryFastTree -threads 16 busco_supermatrix.fasta > busco_supermatrix.tree
```

VeryFastTree is used here as a faster drop-in alternative to FastTree, which matters given how large a concatenated supermatrix across hundreds of BUSCO genes and genomes can get.

## 3. Helixer annotation

Documentation for the Helixer gene annotation step will be added here once that part of the pipeline is in place.

## 4. SignalP 2

Documentation for the SignalP 2 signal peptide prediction step will be added here once that part of the pipeline is in place.

## 5. Predector

Documentation for the Predector effector prediction step will be added here once that part of the pipeline is in place.

## 6. Sequence clustering (TRIBE-MCL)

Documentation for the TRIBE-MCL sequence clustering step will be added here once that part of the pipeline is in place.

## 7. AlphaFold 3

Documentation for the AlphaFold 3 structure prediction step will be added here once that part of the pipeline is in place. This step may change later.

## References

References are numbered in Vancouver style, in the order the corresponding tool first appears in the pipeline above. Entries for Helixer, SignalP 2, Predector, TRIBE-MCL, and AlphaFold 3 will be appended here as those parts of the pipeline are documented.

1. O'Leary NA, Cox E, Holmes JB, Anderson WR, Falk R, Hem V, Tsuchiya MTN, Schuler GD, Zhang X, Torcivia J, Ketter A, Breen L, Cothran J, Bajwa H, Tinne J, Meric PA, Hlavina W, Schneider VA. 2024. Exploring and retrieving sequence and metadata for species across the tree of life with NCBI Datasets. Scientific Data 11(1):732. DOI: [10.1038/s41597-024-03571-y](https://doi.org/10.1038/s41597-024-03571-y).
2. Manni M, Berkeley MR, Seppey M, Simão FA, Zdobnov EM. 2021. BUSCO Update: Novel and Streamlined Workflows along with Broader and Deeper Phylogenetic Coverage for Scoring of Eukaryotic, Prokaryotic, and Viral Genomes. Molecular Biology and Evolution 38(10):4647-4654. DOI: [10.1093/molbev/msab199](https://doi.org/10.1093/molbev/msab199).

## License

See LICENSE for details (MIT).
