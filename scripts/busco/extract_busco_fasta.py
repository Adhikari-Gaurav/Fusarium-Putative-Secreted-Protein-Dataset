#! /usr/bin/env python3

import os
import sys
import glob
import collections
from pathlib import Path
import concurrent.futures


def process_result_item(item, target_dir, output_dir):
    i, (k, v) = item
    print(f"[{i}] Start processing: {k}")
    # Get BUSCO result paths
    single_copy_genes = glob.glob(
        str(target_dir / f"*/run_*/busco_sequences/single_copy_busco_sequences/{k}")
    )
    output_file = output_dir / k

    output_data = []
    for single_copy_gene in single_copy_genes:
        # Get directory name (sample name)
        try:
            dir_name = Path(single_copy_gene).parts[-5]
        except IndexError:
            dir_name = "unknown"
        try:
            with open(single_copy_gene) as f2:
                for line in f2:
                    if line.startswith(">"):
                        output_data.append(f">{dir_name}\n")
                    else:
                        output_data.append(line)
        except Exception as e:
            print(f"Error reading {single_copy_gene}: {e}", file=sys.stderr)
    # Create output directory
    output_file.parent.mkdir(parents=True, exist_ok=True)
    # Overwrite output file
    with open(output_file, "w") as f1:
        f1.writelines(output_data)
    print(f"[{i}] Finished processing: {k} -> {output_file}")


def main():
    if len(sys.argv) != 4:
        print(
            f"Usage: {sys.argv[0]} <target_dir> <output_dir> <n_threads>",
            file=sys.stderr,
        )
        sys.exit(1)

    target_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    n_threads = int(sys.argv[3])

    # Get BUSCO gene list
    single_copy_seqs = glob.glob(
        str(target_dir / "*/run_*/busco_sequences/single_copy_busco_sequences/*.faa")
    )
    single_copy_seqs = [
        os.path.basename(single_copy_seq) for single_copy_seq in single_copy_seqs
    ]
    results = dict(collections.Counter(single_copy_seqs))
    print(f"Found {len(results)} BUSCO gene types to process.")

    # Parallel processing
    with concurrent.futures.ThreadPoolExecutor(max_workers=n_threads) as executor:
        futures = [
            executor.submit(process_result_item, item, target_dir, output_dir)
            for item in enumerate(results.items())
        ]
        for idx, future in enumerate(concurrent.futures.as_completed(futures), 1):
            try:
                future.result()
                print(f"Progress: {idx}/{len(futures)} files processed.")
            except Exception as exc:
                print(f"Thread generated an exception: {exc}", file=sys.stderr)


if __name__ == "__main__":
    main()
