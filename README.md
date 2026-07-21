# Fusarium-Effector-Dataset---Effectoromics

Effector dataset and analysis scripts for Fusarium effectoromics research.

## Overview

This repository collects the scripts and data used for identifying and characterizing candidate effector proteins in Fusarium genomes.

## Data acquisition

Genome assemblies are pulled down using NCBI's Datasets command-line tool (`datasets`), installed via conda:

```
conda create -n ncbi_datasets
conda activate ncbi_datasets
conda install -c conda-forge ncbi-datasets-cli
```

With a list of assembly accessions ready, genomes are downloaded in dehydrated form first (metadata only, no sequence data yet) and then rehydrated to pull down the actual files:

```
datasets download genome accession --inputfile accessions.txt --dehydrated
unzip ncbi_dataset.zip -d genomes
datasets rehydrate --directory genomes
```

Downloading dehydrated first and rehydrating after keeps the initial pull light, and the full sequence data only gets fetched once you're actually ready to use it.

`accessions.txt` is just a plain text file listing the genomes you want, one NCBI assembly accession per line (something like `GCA_000149555.1`). It's basically the shopping list you hand to the `datasets` tool so it knows exactly which genomes to go fetch.

## Repository contents

The repository includes scripts for downloading accessions via NCBI command-line tools, analysis scripts for effector prediction and characterization, and supporting data files.

## Citing NCBI Datasets

This project relies on NCBI's Datasets tool to fetch genome data, so if you use or build on this work, please also cite:

O'Leary NA, Cox E, Holmes JB, Anderson WR, Falk R, Hem V, Tsuchiya MTN, Schuler GD, Zhang X, Torcivia J, Ketter A, Breen L, Cothran J, Bajwa H, Tinne J, Meric PA, Hlavina W, Schneider VA. Exploring and retrieving sequence and metadata for species across the tree of life with NCBI Datasets. Sci Data. 2024 Jul 5;11(1):732. doi: 10.1038/s41597-024-03571-y.

## License

See LICENSE for details (MIT).
