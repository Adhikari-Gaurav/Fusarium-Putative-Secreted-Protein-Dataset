#!/usr/bin/env python3

import argparse
import json
from typing import List, Optional, Dict, Any, Tuple
import sys
import os

def parse_fasta(fasta_file: str) -> List[Tuple[str, str]]:
    sequences = []
    current_id = None
    current_sequence = []
    try:
        with open(fasta_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                if line.startswith('>'):
                    if current_id is not None:
                        sequences.append((current_id, ''.join(current_sequence)))
                        current_sequence = []
                    current_id = line[1:].split()[0]
                else:
                    current_sequence.append(line)
            if current_id is not None and current_sequence:
                sequences.append((current_id, ''.join(current_sequence)))
        return sequences
    except FileNotFoundError:
        print(f"Error: Could not find FASTA file: {fasta_file}")
        sys.exit(1)

def determine_sequence_type(sequence: str) -> str:
    sequence = sequence.upper()
    if all(c in 'ACGT' for c in sequence):
        return 'dna'
    elif all(c in 'ACGU' for c in sequence):
        return 'rna'
    else:
        return 'protein'

def generate_job_name(seq_name: str, seq_count: int,
                     ligand_name: Optional[str] = None,
                     ligand_count: Optional[int] = None,
                     seed: Optional[int] = None,
                     suffix: Optional[str] = None) -> str:
    sanitized_seq_name = seq_name.replace(".", "_").replace("^", "_").replace("-", "_")
    name_parts = [sanitized_seq_name]
    if seq_count > 1:
        name_parts.append(str(seq_count))
    if ligand_name:
        name_parts.append(ligand_name)
        if ligand_count and ligand_count > 1:
            name_parts.append(str(ligand_count))
    if seed is not None:
        name_parts.append(f"seed{seed}")
    if suffix:
        name_parts.append(suffix)
    return "_".join(name_parts)

def build_sequence_entry(sequence: str, seq_copies: int, use_structure_template: bool, max_template_date: Optional[str]) -> Dict[str, Any]:
    seq_type = determine_sequence_type(sequence)
    sequence_upper = sequence.upper()
    if seq_type == 'protein':
        entry: Dict[str, Any] = {
            "proteinChain": {
                "sequence": sequence_upper,
                "count": seq_copies
            }
        }
        if use_structure_template:
            entry["proteinChain"]["useStructureTemplate"] = True
        if max_template_date:
            entry["proteinChain"]["maxTemplateDate"] = max_template_date
        return entry
    elif seq_type == 'dna':
        return {
            "dnaChain": {
                "sequence": sequence_upper,
                "count": seq_copies
            }
        }
    else:
        return {
            "rnaChain": {
                "sequence": sequence_upper,
                "count": seq_copies
            }
        }

def create_af3_jobs(
    fasta_file: str,
    seq_copies: int = 1,
    ligand: Optional[str] = None,
    ligand_copies: Optional[int] = None,
    model_seeds: Optional[List[int]] = None,
    suffix: Optional[str] = None,
    output_dir: str = ".",
    use_structure_template: bool = False,
    max_template_date: Optional[str] = None,
    single_json: Optional[str] = None,
) -> None:
    os.makedirs(output_dir, exist_ok=True)
    sequences = parse_fasta(fasta_file)
    all_jobs: List[Dict[str, Any]] = []

    for seq_id, sequence in sequences:
        seeds_to_process = model_seeds if model_seeds else [None]
        for seed in seeds_to_process:
            job_name = generate_job_name(
                seq_name=seq_id,
                seq_count=seq_copies,
                ligand_name=ligand,
                ligand_count=ligand_copies,
                seed=seed,
                suffix=suffix
            )
            job_data: Dict[str, Any] = {
                "name": job_name,
                "modelSeeds": [seed] if seed is not None else [],
                "sequences": []
            }
            sequence_entry = build_sequence_entry(
                sequence=sequence,
                seq_copies=seq_copies,
                use_structure_template=use_structure_template,
                max_template_date=max_template_date
            )
            job_data["sequences"].append(sequence_entry)
            if ligand:
                ligand_data = {
                    "ligand": {
                        "ligand": ligand,
                        "count": ligand_copies if ligand_copies else 1
                    }
                }
                job_data["sequences"].append(ligand_data)
            all_jobs.append(job_data)
            if not single_json:
                output_data = [job_data]
                output_file = os.path.join(output_dir, f"{job_name}.json")
                with open(output_file, 'w') as f:
                    json.dump(output_data, f, indent=2)
                print(f"Created AlphaFold 3 input file: {output_file}")

    if single_json:
        target_path = single_json
        if not os.path.isabs(target_path):
            target_path = os.path.join(output_dir, target_path)
        os.makedirs(os.path.dirname(target_path), exist_ok=True)
        with open(target_path, "w") as f:
            json.dump(all_jobs, f, indent=2)
        print(f"Wrote {len(all_jobs)} jobs into single JSON: {target_path}")

def main():
    parser = argparse.ArgumentParser(description='Generate AlphaFold 3 input JSON files')
    parser.add_argument('--fasta', required=True, help='FASTA file containing sequences')
    parser.add_argument('--seq-copies', type=int, default=1, help='Number of copies of each sequence (default: 1)')
    parser.add_argument('--ligand', help='Ligand specification (optional)')
    parser.add_argument('--ligand-copies', type=int, help='Number of ligand copies (optional)')
    parser.add_argument('--seeds', type=int, nargs='+', help='Optional model seed numbers')
    parser.add_argument('--suffix', help='Optional suffix for job names')
    parser.add_argument('--output-dir', default='.', help='Output directory (default: current directory)')
    parser.add_argument('--use-structure-template', action='store_true', help='Include "useStructureTemplate": true on protein chains')
    parser.add_argument('--max-template-date', type=str, help='Include "maxTemplateDate" on protein chains (e.g., 2025-02-03)')
    parser.add_argument('--single-json', type=str, help='Write ALL generated jobs into this single JSON file')
    args = parser.parse_args()
    create_af3_jobs(
        fasta_file=args.fasta,
        seq_copies=args.seq_copies,
        ligand=args.ligand,
        ligand_copies=args.ligand_copies,
        model_seeds=args.seeds,
        suffix=args.suffix,
        output_dir=args.output_dir,
        use_structure_template=args.use_structure_template,
        max_template_date=args.max_template_date,
        single_json=args.single_json,
    )

if __name__ == '__main__':
    main()
