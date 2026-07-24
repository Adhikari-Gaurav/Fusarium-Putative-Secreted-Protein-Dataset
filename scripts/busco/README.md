# BUSCO analysis

This is step 2 of the overall pipeline (see the [root README](../../README.md) for the full pipeline index). Once genomes are on disk (step 1, data acquisition), each assembly is run through BUSCO separately, one BUSCO run per genome against whichever lineage dataset is appropriate, to assess completeness and, more importantly for this project, to pull out single-copy orthologous genes shared across all the assemblies.

The scripts here pick up after that per-genome BUSCO run has already been done. They summarize the BUSCO scores across all genomes, extract the single-copy orthologs that are shared across assemblies into one FASTA file per gene, align and trim each of those gene sets, patch in gap sequences for any assembly missing a gene (so the alignment stays a consistent width), concatenate everything into one supermatrix, and build a phylogenetic tree from that supermatrix.

`busco_pipeline.sh` is the SLURM batch script that runs the whole thing end to end on an HPC cluster (adjust the `#SBATCH` partition and resource requests for your own cluster). It expects a `BASE_DIR` pointing at a working directory that contains a `busco_results` folder (the raw, per-genome BUSCO output), and it creates `busco_seqs`, `busco_seqs_aln`, `busco_seqs_aln_filled`, and `busco_supermatrix` folders under that same `BASE_DIR` as it runs. Point it at your own project directory like this:

```
BASE_DIR=/path/to/your/project sbatch busco_pipeline.sh
```

The individual Python scripts can also be run on their own outside of the batch script, which is how they're described below.

## Contents
1. [Summarize BUSCO scores](#1-summarize-busco-scores)
2. [Extract single-copy ortholog sequences](#2-extract-single-copy-ortholog-sequences)
3. [Align and trim each ortholog](#3-align-and-trim-each-ortholog)
4. [Fill in missing samples](#4-fill-in-missing-samples)
5. [Concatenate into a supermatrix](#5-concatenate-into-a-supermatrix)
6. [Build the phylogenetic tree](#6-build-the-phylogenetic-tree)

## 1. Summarize BUSCO scores

`00_get_busco_results.py` walks a directory of per-genome BUSCO output folders and pulls the completeness scores out of each one's `short_summary.*.json` file, writing everything out as a single tab-separated table (one row per genome).

```
python3 00_get_busco_results.py busco_results > busco_summary.tsv
```

This is mainly a sanity check: it's an easy way to see, across every genome at once, how complete each assembly's BUSCO run was before trusting any of them for downstream analysis.

## 2. Extract single-copy ortholog sequences

`extract_busco_fasta.py` looks inside each genome's BUSCO output for the single-copy orthologous genes it found, and regroups them by gene rather than by genome. For every BUSCO gene ID that shows up in at least one genome, it collects the corresponding sequence from every genome that has it and writes them all into one FASTA file per gene, with each sequence's header renamed to the genome's own identifier (so sequences from the same gene across different genomes end up in the same file, ready for alignment).

```
python3 extract_busco_fasta.py busco_results busco_seqs 16
```

The three arguments are the BUSCO results directory, the output directory for the per-gene FASTA files, and the number of threads to use (the genomes are processed in parallel).

## 3. Align and trim each ortholog

Each per-gene FASTA file from the previous step is aligned with MAFFT, then trimmed with ClipKit to remove poorly aligned, gappy columns:

```
mafft gene.faa > gene_aln.faa
clipkit gene_aln.faa -m gappy -g 0.9 -o gene_aln.clip.faa
```

The `-m gappy -g 0.9` setting removes alignment columns that are more than 90% gaps, which helps cut down on noisy, uninformative sites before the tree-building step. In the batch script this runs in parallel across all the per-gene files.

## 4. Fill in missing samples

Not every genome necessarily has a hit for every BUSCO gene, so an alignment for a given gene might be missing one or more genomes. `fill_missing_samples.py` compares each aligned, trimmed gene file against the full list of genomes and, for any genome missing from that gene's alignment, adds a gap-only sequence (a row of `-` characters matching the alignment's width) so every gene file ends up with a row for every genome.

```
python3 fill_missing_samples.py busco_results busco_seqs_aln busco_seqs_aln_filled --max-missing-ratio 0.1
```

`--max-missing-ratio` sets a ceiling on how much missing data is tolerated for a given gene: if more than that fraction of genomes are missing the gene, that gene is skipped entirely rather than padded out, since a gene that's mostly gaps isn't contributing much real signal to the tree. A value of `0.1` means a gene is only kept if at most 10% of genomes are missing it.

## 5. Concatenate into a supermatrix

Once every kept gene alignment has one row per genome, they're concatenated end to end into a single supermatrix, one row per genome, using seqkit:

```
seqkit concat --full busco_seqs_aln_filled/*_aln.clip.faa > busco_supermatrix.all.fasta
```

If there are specific genomes to exclude from the final tree (for example, an assembly that turned out to be low quality), list their accessions one per line in an `exclude_accessions.txt` file in the output directory; the batch script checks for this file and, if it's present and non-empty, removes those accessions from the supermatrix before proceeding. If no such file exists, the full supermatrix is used as-is.

## 6. Build the phylogenetic tree

The final supermatrix is used to build a phylogenetic tree with VeryFastTree:

```
VeryFastTree -threads 16 busco_supermatrix.fasta > busco_supermatrix.tree
```

The resulting `.tree` file is a standard Newick-format tree that can be opened in any typical tree-viewing software.

## Citation

If you use this step, please also cite BUSCO itself, in addition to the citations listed in the [root README](../../README.md#references):

Manni M, Berkeley MR, Seppey M, Simão FA, Zdobnov EM. BUSCO Update: Novel and Streamlined Workflows along with Broader and Deeper Phylogenetic Coverage for Scoring of Eukaryotic, Prokaryotic, and Viral Genomes. Mol Biol Evol. 2021;38(10):4647-4654. DOI: 10.1093/molbev/msab199.
