# Assignment 2: RAG and Iterative Tool Feedback for Hardware Debugging

[Back to the project overview](../README.md)

This stage extends the Assignment 1 RTL workflow into a debugging agent for a single-cycle RV32I processor. It adds `pc_unit`, `branch_unit`, `memory_access`, and `datapath`, and compares generation and repair with baseline prompting, retrieval, and retrieval plus structured tool feedback.

## Start here

- [Final report](837004069_A2_Report.pdf): implementation explanation, experimental comparisons, plots, and final analysis.
- [Implementation and reproduction guide](A2_student/README.md): package layout and commands.
- [Evidence index](A2_student/submission_artifacts/README.md): saved results organized by task.

## Tasks

| Task | Work | Evidence |
|---|---|---|
| 1 | Build a vector index of the knowledge base and inspect five retrieval queries. | [Index and query outputs](A2_student/submission_artifacts/task1/) |
| 2 | Implement retrieval context, tool feedback, candidate ranking, and bounded repair. | [Agent snapshots and smoke run](A2_student/submission_artifacts/task2/) |
| 3 | Generate and integrate processor modules; diagnose and repair seeded bugs. | [Run logs and bug reports](A2_student/submission_artifacts/task3/) |
| 4 | Compare three arms over nine unseeded trials and two arms over six seeded trials. | [Trial records, RTL, and metrics](A2_student/submission_artifacts/task4/) |
| 5 | Validate the restored processor and analyze the complete workflow. | [Final sample-suite transcripts](A2_student/submission_artifacts/task5/) and the report above |

## Working directory and setup

From the repository root:

```bash
cd assignment_02_rag_debugging/A2_student
conda env create -f environment.yml
```

Activate the environment named in `environment.yml`, configure your provider key locally, and run `bash check_setup.sh`. If using an existing compatible environment, install the dependencies from `requirements.txt`. Icarus Verilog (`iverilog` and `vvp`) must be available on `PATH`.

All commands in the package README run from `A2_student/`. The original package layout is retained so scripts, specifications, retrieval data, and evidence paths remain compatible. The saved `.rag_index/` is included for the archived retrieval setup; it can also be rebuilt from `rag_dataset/`.

The report is supplied as the final PDF. Raw logs and task-organized evidence are retained together because the metrics script reads the original experiment records and the report references the staged evidence. Historical absolute paths within logs describe the machines used for those runs.
