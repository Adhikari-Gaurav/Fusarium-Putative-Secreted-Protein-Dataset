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

## Repository contents

The repository includes scripts for downloading accessions via NCBI command-line tools, analysis scripts for effector prediction and characterization, and supporting data files.

## License

See LICENSE for details (MIT).
