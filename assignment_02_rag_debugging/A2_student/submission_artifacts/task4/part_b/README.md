# Task 4 Part B: seeded datapath ablation

These are new runs of the supplied `bugs/datapath_buggy.sv`, made on 28 September 2026 with the unchanged debugging agent, TAMU provider, and `gpt-5.4`.

- `rag/`: three seed-only trials with retrieval enabled and repairs disabled.
- `rag_feedback/`: three trials allowing up to five repairs after the seed.
- Each arm contains `ablation_<arm>_<n>.json`, `datapath_<n>.sv`, a `.terminal.txt` transcript, and an `.exit_code.txt` file.
- `inputs/`: copies of the supporting RTL and original seed, index metadata, and source hashes captured before the experiment.
- Root timestamp and Python-version files record the execution context.

The retained RTL is the final/best candidate for that run; the original seed is also preserved in `inputs/`. Intermediate repair candidates are not retained by the supplied agent. Terminal transcripts contain what the driver prints; captured internal compiler/simulator stdout and stderr are not printed or included in the current JSON schema.

The orchestrator is the package-root file `task4_seeded.sh`. It refuses to overwrite this experiment directory. The script runs each trial sequentially and restores the initial state of `rtl/datapath.sv` after archiving results. Cached embedding weights are loaded offline; TAMU API access is used only for feedback repairs.

These runs are separate from the four Task 3 demonstrations under `repair_logs/` and the nine unseeded Part A trials. Metrics for both parts are computed by `submission_artifacts/task4/summarize_metrics.py`.
