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

Documentation for the BUSCO completeness assessment step will be added here once that part of the pipeline is in place.

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

References are numbered in Vancouver style, in the order the corresponding tool first appears in the pipeline above. Entries for BUSCO, Helixer, SignalP 2, Predector, TRIBE-MCL, and AlphaFold 3 will be appended here as those parts of the pipeline are documented.

1. O'Leary NA, Cox E, Holmes JB, Anderson WR, Falk R, Hem V, Tsuchiya MTN, Schuler GD, Zhang X, Torcivia J, Ketter A, Breen L, Cothran J, Bajwa H, Tinne J, Meric PA, Hlavina W, Schneider VA. 2024. Exploring and retrieving sequence and metadata for species across the tree of life with NCBI Datasets. Scientific Data 11(1):732. DOI: [10.1038/s41597-024-03571-y](https://doi.org/10.1038/s41597-024-03571-y).

## License

See LICENSE for details (MIT).
