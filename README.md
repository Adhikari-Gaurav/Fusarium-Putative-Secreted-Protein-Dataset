# Fusarium-Effector-Dataset---Effectoromics

Effector dataset and analysis scripts for Fusarium effectoromics research.

## Overview

This repository collects the scripts and data used for identifying and characterizing candidate effector proteins in Fusarium genomes.

## Data acquisition

Genome and protein accession files are downloaded using NCBI-provided command-line tools (such as `datasets`, Entrez Direct's `efetch`/`esearch`, or SRA Toolkit's `prefetch`, depending on the script). The general workflow:

1. Identify target accessions on NCBI (genome assemblies, protein sets, or SRA runs).
2. Download the corresponding files using the NCBI CLI tools.
3. Run the downstream analysis scripts on the retrieved data.

## Repository contents

The repository includes scripts for downloading accessions via NCBI command-line tools, analysis scripts for effector prediction and characterization, and supporting data files.

## License

See LICENSE for details (MIT).

