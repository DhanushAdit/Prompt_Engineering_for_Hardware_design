# ECEN 689 Assignment 2 Submission

This package contains the completed Assignment 2 implementation, RTL, experiment logs, and task-organized submission evidence. The [final report](../837004069_A2_Report.pdf) is stored one directory above this package.

Do not include API keys in the submission. The local `.env` file was removed from this package before staging.

## Top-level structure

| Path | Contents |
|---|---|
| `agent/` | Debugging agent implementation, including iterative generation, keep-best repair, tool feedback parsing, and the run driver. |
| `rag/` | RAG index build/query code and retrieval interface. |
| `rag_dataset/` | Knowledge-base documents used to build `.rag_index/`. |
| `.rag_index/` | Built FAISS index, chunks, and metadata used for retrieval experiments. |
| `rtl/` | Final restored passing processor RTL used for Task 5. |
| `rtl_good_backup/` | Passing processor backup saved after Task 3 and restored for Task 5. This folder stays at the package root, not inside `rtl/`. |
| `task_3_rtl/` | Snapshot of the Task 3 generated/passing RTL. |
| `bugs/` | Seeded buggy modules supplied for repair experiments. |
| `bugs_found/` | Short bug reports for each seeded buggy block. |
| `logs/` | Original generation/debugging run JSON records. |
| `repair_logs/` | Seeded repair JSON logs for `pc_unit`, `branch_unit`, `memory_access`, and `datapath`. |
| `ablation_experiment/` | Original Task 4 ablation logs, generated RTL snapshots, and seeded Part B trial outputs. |
| `scripts/` | Provided run scripts for module and full-processor checks. |
| `specs/`, `testbench/`, `vectors/`, `programs/` | Assignment specifications and sample verification infrastructure. |
| `submission_artifacts/` | Task-organized evidence folder for grading and report cross-reference. |

## Task evidence map

| Task | Evidence location |
|---|---|
| Task 1 | `submission_artifacts/task1/` contains the index-build output and five sample retrieval-query outputs with observations. |
| Task 2 | `submission_artifacts/task2/` contains the smoke-run JSON and source snapshots for the completed Phase B-F agent logic. |
| Task 3 | `submission_artifacts/task3/` contains generation logs, repair logs, seeded bug reports, and the saved passing RTL backup. |
| Task 4 | `submission_artifacts/task4/` contains Part A/Part B ablation JSON logs, RTL snapshots, terminal transcripts, exit codes, and computed metrics CSV/JSON files. |
| Task 5 | `submission_artifacts/task5/` contains the restored-processor full-suite transcript and a local-copy rerun transcript confirming all sample programs pass. |

## Reproduction commands

Build or refresh the RAG index from the package root:

```bash
python -m rag.build_index --dataset rag_dataset --index-dir .rag_index
```

Run the five Task 1 sample queries from the package root:

```bash
python -m rag.query "controller pcsrc branch logic" --index-dir .rag_index -k 3 --json
python -m rag.query "datapath module interfaces ALUSrcBD immediate register" --index-dir .rag_index -k 3 --json
python -m rag.query "pc_unit synchronous reset PC plus 4" --index-dir .rag_index -k 3 --json
python -m rag.query "branch signed unsigned comparison RV32I" --index-dir .rag_index -k 3 --json
python -m rag.query "memory access LB sign extension LBU byte enable" --index-dir .rag_index -k 3 --json
```

Run a debug-agent example:

```bash
python agent/run_debug_agent.py --module pc_unit --arm rag_feedback --provider tamu --log-file logs/pc_unit_smoke.json
```

Run the final restored processor sample suite:

```bash
bash scripts/run_all_sample.sh
```

Recompute Task 4 metrics:

```bash
python submission_artifacts/task4/summarize_metrics.py
```
