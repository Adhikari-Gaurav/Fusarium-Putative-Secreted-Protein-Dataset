# TRIBE-MCL sequence clustering

This is step 6 of the overall pipeline (see the [root README](../../README.md) for the full pipeline index). By this point, candidate secreted proteins have already been through signal peptide prediction (SignalP 2) and effector prediction/filtering (Predector), leaving a combined FASTA of putative secreted protein candidates across all genomes. This step groups those candidates into families based on sequence similarity using TRIBE-MCL, an approach that runs an all-against-all BLASTP search and then applies Markov clustering (MCL) to the resulting similarity network, so that related candidates end up grouped into the same "tribe" instead of being treated as unrelated singletons.

## Contents
1. [Trim sequences to their mature region](#1-trim-sequences-to-their-mature-region)
2. [Cluster sequences with TRIBE-MCL](#2-cluster-sequences-with-tribe-mcl)
3. [Convert MCL output into a tribe list](#3-convert-mcl-output-into-a-tribe-list)
4. [Extract sequences for each tribe](#4-extract-sequences-for-each-tribe)

## 1. Trim sequences to their mature region

Script: [`scripts/tribemcl/01_trim_fasta_maturity.py`](01_trim_fasta_maturity.py)

Before clustering, each candidate sequence is trimmed down to just its predicted mature region: the part of the protein left over once the signal peptide (and, where predicted, a cleaved propeptide) has been removed. The script looks for an `NNCleavageSite=<position>` tag in each FASTA header, written there by an earlier prediction step, and uses that position to cut the sequence, keeping only the mature portion and discarding everything before the cleavage site. Sequences without a `NNCleavageSite=` tag are skipped entirely, since there's no cleavage position to trim at. This matters for the BLAST search in the next step: leaving the signal peptide/propeptide in place would add sequence that isn't part of the biologically relevant secreted protein and can produce superficial local similarity between otherwise unrelated candidates, so trimming down to the mature sequence first keeps the similarity comparisons focused on the part of the protein that actually matters.

```
BASE_DIR=/path/to/your/project python3 01_trim_fasta_maturity.py
```

This reads `combined_filtered.fasta` from `BASE_DIR` and writes `combined_filtered_trimmed_matured.fasta`. That output is the input the next step expects, just under a different name (`combined_putative_secreted_proteins.fasta`); rename or copy the trimmed FASTA to that filename in `BASE_DIR` before submitting step 2, or edit `INPUT_FASTA` in `02_run_tribemcl.sh` to point at it directly.

## 2. Cluster sequences with TRIBE-MCL

Script: [`scripts/tribemcl/02_run_tribemcl.sh`](02_run_tribemcl.sh)

This is the SLURM batch script that does the actual clustering, and it's the one you submit directly with `sbatch` (adjust the `#SBATCH` partition and resource requests, and uncomment/set `--mail-user` if you want job notifications, for your own cluster). It runs in three stages. First, `makeblastdb` builds a BLAST protein database from the input FASTA, and `blastp` searches that same FASTA against itself (an all-against-all search) with an e-value cutoff of 1e-10, producing a tabular hit list of which sequences resemble which. Second, that BLAST output is converted into the input format MCL expects: `mcxdeblast` reformats the BLAST hits into a simple abc-format similarity list, and `mcxload` loads that into MCL's native matrix format. Third, `mcl` itself clusters the resulting similarity network using an inflation parameter of `-I 1.4`, which controls how tightly or loosely sequences get grouped (lower inflation values produce larger, looser clusters; higher values produce smaller, tighter ones). At the end, the script automatically calls `03_get_tribes.pl` on the raw MCL output to produce a readable tribe list, so that script doesn't need to be run separately as part of the normal workflow.

```
BASE_DIR=/path/to/your/project sbatch 02_run_tribemcl.sh
```

This expects `combined_putative_secreted_proteins.fasta` in `BASE_DIR` (see the note at the end of step 1) and writes everything into `BASE_DIR/tribemcl_putative_secreted/`, including the BLAST hits, the MCL matrix and cluster output, and the final tribe list.

## 3. Convert MCL output into a tribe list

Script: [`scripts/tribemcl/03_get_tribes.pl`](03_get_tribes.pl)

Raw MCL output is just one cluster per line, with cluster members separated by tabs, which isn't a particularly convenient format to work with downstream. This small script reformats that into a FASTA-header-style list: each member of a cluster is printed on its own line prefixed with `>`, and each cluster is terminated with a `//` separator line. This is the script step 2 calls automatically at the end of its run, so under normal use you won't need to run it by hand; it's documented here mainly because it's a separate file, and because it can be rerun manually against any MCL output file if you ever need to regenerate a tribe list without rerunning the whole BLAST and clustering step.

```
perl 03_get_tribes.pl out.some_mcl_output.I14 > tribe_list.tribes
```

## 4. Extract sequences for each tribe

Script: [`scripts/tribemcl/04_fetch_tribe_members.pl`](04_fetch_tribe_members.pl)

The tribe list from step 2/3 only contains sequence names, not the sequences themselves, so this final script goes back to the original FASTA and pulls out the actual sequence for every member of every tribe, writing them all into one output FASTA with headers renamed to include the tribe number (for example `>Tribe1_<original_name>`), so sequences belonging to the same cluster are easy to identify and group by name alone. It reports how many sequences it found and lists any tribe members it couldn't locate in the FASTA, which is worth checking, since a mismatch there usually means the FASTA used for BLAST/MCL and the FASTA used here aren't the same file.

```
BASE_DIR=/path/to/your/project perl 04_fetch_tribe_members.pl
```

By default this reads `BASE_DIR/tribemcl_putative_secreted/putative_secreted_e10_mcl.tribes` (the tribe list produced by step 2) and `BASE_DIR/combined_putative_secreted_proteins.fasta` (the same FASTA used for the BLAST search), and writes `putative_secreted_e10_mcl_tribes.faa` alongside the tribe list.

## Citation

If you use this step, please also cite BLAST+ and the TRIBE-MCL clustering method, in addition to the citations listed in the [root README](../../README.md#references):

Camacho C, Coulouris G, Avagyan V, Ma N, Papadopoulos J, Bealer K, Madden TL. BLAST+: architecture and applications. BMC Bioinformatics. 2009;10:421. DOI: 10.1186/1471-2105-10-421.

Enright AJ, Van Dongen S, Ouzounis CA. An efficient algorithm for large-scale detection of protein families. Nucleic Acids Res. 2002;30(7):1575-1584. DOI: 10.1093/nar/30.7.1575.
