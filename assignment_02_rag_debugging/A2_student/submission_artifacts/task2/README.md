# Task 2 evidence

Store the completed agent-phase evidence, one end-to-end smoke-run JSON record, tool feedback, and the repair-policy explanation here.

## Phases B–F

- **Phase B — initial context:** combines the module task with its official specification. When RAG is enabled, it retrieves the top-k relevant knowledge chunks, records their source/text, and appends them to the initial LLM prompt.
- **Phase C — classification:** maps tool results to `pass`, `compile_error`, or `sim_fail` using the return code and compiler/elaboration diagnostics.
- **Phase D — generate and test:** asks the LLM for complete RTL, writes it to `rtl/<module>.sv`, runs the configured Icarus flow, and records the iteration status and return code.
- **Phase E — keep-best repair policy:** ranks results as `compile_error < sim_fail < pass`. The first candidate becomes the best. Equal or higher-ranked candidates replace it; a worse candidate is discarded, the previous best RTL is restored, and the log records `kept_best: true`.
- **Phase F — feedback:** after a failed run, appends the structured tool feedback and asks the LLM for a complete revised module. The loop stops on the first pass or after at most five repairs.

This policy prevents a repair from degrading the best result while giving later attempts the latest compiler or simulation evidence.
