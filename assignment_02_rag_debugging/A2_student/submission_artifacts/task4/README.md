# Task 4 Evidence

Store all Part A and Part B ablation logs, the pass-rate and repair-count metrics, and the interpretation here.

## Evidence locations

- `part_a/baseline/`, `part_a/rag/`, `part_a/rag_feedback/`: nine unseeded JSON logs and RTL snapshots.
- `part_b/rag/`, `part_b/rag_feedback/`: six seeded JSON logs, final RTL copies, terminal transcripts, and exit codes.
- `ablation_run_metrics.csv`: one row per trial, including iteration trace, source path and SHA-256.
- `ablation_summary.csv` and `ablation_metrics.json`: pass rates, failure counts, and successful-run repair statistics, separated by part and arm.
- Detailed interpretation and plots: [final report](../../../837004069_A2_Report.pdf).

Recalculate metrics from the package root with `python submission_artifacts/task4/summarize_metrics.py`. Iteration 0 is the initial candidate and counts as zero repairs. Failed trials are excluded from mean/range calculations. Duplicate baseline logs under `logs/` are not counted again.
