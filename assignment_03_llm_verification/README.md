# Assignment 3: LLM-Guided Verification of a Pipelined RV32I Processor

[Back to the project overview](../README.md)

This stage extends the earlier RTL generation and debugging work to a five-stage pipelined RV32I processor. It completes forwarding, load-use hazard handling, and control-flow flush logic, then uses an LLM verification agent to generate directed programs, evaluate mutation detection, close measured coverage gaps, and create runtime assertions.

## Start here

- [Final report](837004069_A3_Report.pdf): design explanation, verification workflow, results, and analysis.
- [Implementation and reproduction guide](A3_student/README.md): package structure, configuration, and exact commands.
- [Saved results](A3_student/results/): generated programs, assertions, coverage, prompts, responses, mutations, and summaries.

## Tasks

| Task | Work | Result and evidence |
|---|---|---|
| 1 | Complete forwarding, load-use detection, and redirect or flush control in the five-stage datapath. | All 13 supplied tests pass; initial coverage is 20 of 21 bins. |
| 2 | Generate directed RV32I programs, calculate signatures with the reference ISS, and evaluate representative RTL mutations. | 22 passing tests detect all five mutation families. |
| 3 | Measure the fixed coverage bins and prompt only for tests targeting observed gaps. | Two AUIPC tests raise coverage from 20 of 21 to 21 of 21 bins. |
| 4 | Generate eight SystemVerilog assertions and validate both activation and correct-core silence. | All eight assertions activate under deliberate violations and remain silent across 24 correct-core tests. |
| 5 | Record provider settings, calls, token usage, results, limitations, and reproduction instructions. | The report and machine-readable records describe the same final experiment. |

## Verification workflow

The agent uses a layered acceptance process rather than trusting model output directly:

1. Claude returns structured JSON descriptions of short RV32I programs.
2. The agent validates and encodes every instruction and appends a signature store.
3. The supplied instruction-set simulator calculates the expected signature.
4. Icarus Verilog runs each program on the selected core and compares the observed signature.
5. The passing suite is evaluated against five deliberately corrupted RTL variants.
6. Coverage is measured on the correct core, and only passing tests that add missing bins are retained.
7. Generated assertions must pass structural checks, fire in targeted activation probes, and remain silent on the correct core.

The saved experiment used TAMU AI Chat with `protected.Claude-Opus-5`, temperature `0.0`, `16384` maximum response tokens, and a global limit of 20 calls. Tasks 2 through 4 used three calls and 19,630 total tokens.

## Reproduction

From the repository root:

```bash
cd assignment_03_llm_verification/A3_student
conda env create -f environment.yml
conda activate ecen689-a3
cp env.example .env
```

Set `TAMUS_AI_CHAT_API_KEY` in the local `.env` file. The credential file is intentionally excluded from the repository.

Run the saved workflow by task:

```bash
bash check_setup.sh
bash scripts/run_task1.sh
bash scripts/run_task2.sh
bash scripts/verify_task2.sh
bash scripts/run_task3.sh
bash scripts/verify_task3.sh
bash scripts/run_task4.sh
bash scripts/verify_task4.sh
```

The generated suite and provider-backed tasks can replace files under `results/`. Use a separate branch or working copy when reproducing the experiment if the archived evidence must remain unchanged.

## Final results

```text
Task 1: 13/13 supplied tests pass; 20/21 coverage bins
Task 2: 22/22 tests pass; all five mutation families detected
Task 3: 24/24 tests pass; 21/21 coverage bins
Task 4: 24/24 tests pass with assertions; no assertion failures
LLM use: 3/20 calls; 19,630 total tokens
```

Provider transcripts and summaries are retained under `A3_student/results/run_records/`. API keys are not included.
