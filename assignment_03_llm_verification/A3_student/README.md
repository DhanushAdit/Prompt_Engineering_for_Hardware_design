# ECEN 689 Assignment 3

This submission implements and verifies a five-stage pipelined RV32I processor. The RTL completes forwarding, load-use hazard detection, and control-flow redirect and flush logic. A TAMU AI Chat verification agent generates directed instruction programs, checks them against the supplied reference model, evaluates mutation detection, closes measured coverage gaps, and generates SystemVerilog assertions.

The saved final experiment uses `protected.Claude-Opus-5` with temperature `0.0`, a maximum response size of `16384` tokens, and a global limit of `20` LLM calls. It used three calls in total. The final suite contains 24 passing tests, reaches 21 of 21 coverage bins, detects all five mutation families, and runs eight assertions without a false positive on the correct core.

## Directory structure

```text
A3_student/
├── README.md                  this reproduction guide
├── README_A3.md               supplied package description
├── check_setup.sh             supplied environment preflight
├── environment.yml            Python 3.11 conda environment
├── env.example                API credential template
├── core/
│   ├── datapath_pipelined.sv  completed five-stage datapath
│   └── submodules/            reused Assignment 2 RTL modules
├── agent/
│   ├── run_agent.py           cumulative Task 2 through Task 4 entry point
│   ├── llm_client.py          TAMU provider and call-budget handling
│   ├── prompts.py             versioned test, coverage, and assertion prompts
│   ├── test_programs.py       JSON parsing, RV32I encoding, seeds, and ISS oracle
│   ├── rtl_runner.py          compilation, simulation, coverage, and assertions
│   ├── mutations.py           five representative RTL mutation families
│   ├── coverage_loop.py       Task 3 coverage-feedback loop
│   └── assertion_loop.py      Task 4 assertion generation and validation
├── scripts/
│   ├── run_task1.sh           supplied-test correctness run
│   ├── run_task2.sh           generated tests and mutation analysis
│   ├── run_task3.sh           coverage-guided test generation
│   ├── run_task4.sh           assertion generation and validation
│   ├── verify_task2.sh        independent Task 2 suite check
│   ├── verify_task3.sh        independent coverage check
│   ├── verify_task4.sh        final suite with assertions
│   └── install_icarus.sh      optional user-local Icarus installation
├── results/
│   ├── tests/                 final 24 generated and seed hex programs
│   ├── assertions.sv          final eight assertions
│   ├── coverage.json          coverage before and after feedback
│   └── run_records/           prompts, responses, summaries, and mutants
├── harness/                   supplied testbenches and Task 1 tests
├── reference/                 supplied RV32I encoders and ISS oracle
├── docs/                      supplied pipeline and verification specifications
└── run_artifacts/             saved terminal validation transcripts
```

Submit the report separately from the assignment folder as `<UIN>_A3_Report.docx`, replacing `<UIN>` in both its filename and cover page with the student UIN.

## Task overview

### Task 1 Core implementation

`core/datapath_pipelined.sv` implements the three required pipeline control regions:

- Memory-stage and Writeback-stage forwarding for both Execute operands, with Memory priority and an x0 guard.
- One-cycle load-use detection using the Execute load destination and both Decode source registers.
- Branch and jump redirection, Fetch and Decode stalls, and Decode and Execute flush controls.

The completed core passes all 13 supplied tests. The supplied suite reaches 20 of 21 coverage bins and misses only `OP_AUIPC`.

### Task 2 Verification agent

The agent combines eight deterministic seed programs with LLM-generated directed programs. Model output is restricted to structured RV32I instruction JSON. The agent validates and encodes each instruction, appends a signature store, and uses `reference/iss.py` to calculate the expected signature. Icarus Verilog then runs the same program on the selected RTL core.

The saved Task 2 run contains 22 passing programs and detects representative bugs in forwarding, x0 integrity, load-use handling, redirect flushing, and branch or jump target generation.

### Task 3 Coverage feedback

The coverage loop first measures the saved Task 2 suite. When bins are missing, the prompt includes the existing test names, each test's observed bins, the cumulative hit bins, and the missing bins. Only passing candidates that add coverage are retained.

The saved run identified `OP_AUIPC` as the only missing bin. Two targeted AUIPC programs raised coverage from 20 of 21 bins to 21 of 21 bins.

### Task 4 Assertions

The assertion loop gives the model the supplied module template and invariant specification. It validates the interface and eight required failure names, deliberately activates every assertion with a synthetic probe, and rejects any assertion that fires on the correct core.

The final `results/assertions.sv` checks x0 read behavior, prevents forwarding into x0, and requires a matching valid producer for every active forwarding selection. All eight checks activate in the probe and remain silent across the 24-test final suite.

### Task 5 Report

The separate report explains the RTL changes, agent design, mutation results, coverage loop, assertions, token and call accounting, limitations, and possible improvements.

## Requirements

- Conda or Miniconda
- Python 3.11
- Icarus Verilog with `iverilog` and `vvp` on `PATH`
- Network access to TAMU AI Chat for Tasks 2 through 4
- A valid TAMU AI Chat API key

No third-party Python packages are required by the submitted agent.

## Configuration

Create the conda environment and local credential file from the assignment root:

```bash
conda env create -f environment.yml
conda activate ecen689-a3
cp env.example .env
```

Edit `.env` and set:

```text
TAMUS_AI_CHAT_API_KEY=your_tamu_key_here
```

The launchers load `A3_student/.env` automatically. Do not include `.env` in the submission archive.

The default reported settings are:

```text
provider: tamu
model: protected.Claude-Opus-5
temperature: 0.0
max_tokens: 16384
max_calls: 20
```

## Reproduction flow

Run every command from `A3_student`.

Check the local toolchain:

```bash
bash check_setup.sh
```

Run and verify each task in sequence:

```bash
bash scripts/run_task1.sh

bash scripts/run_task2.sh
bash scripts/verify_task2.sh

bash scripts/run_task3.sh
bash scripts/verify_task3.sh

bash scripts/run_task4.sh
bash scripts/verify_task4.sh
```

The required cumulative agent command is also available directly:

```bash
python3 agent/run_agent.py \
  --provider tamu \
  --out results \
  --core core \
  --max-calls 20
```

This direct command runs Tasks 2 through 4 with the default model and settings. Use the task launchers when reproducing and inspecting each stage separately.

## Expected final results

```text
Task 1: 13/13 supplied tests pass; 20/21 coverage bins
Task 2: 22/22 tests pass; all five mutation families detected
Task 3: 24/24 tests pass; coverage increases to 21/21 bins
Task 4: 24/24 tests pass with assertions; no assertion failures
LLM usage: 3/20 calls; 19,630 total tokens
```

The authoritative machine-readable evidence is under `results/run_records/`. Provider transcripts are in `calls/`, `coverage_calls/`, and `assertion_calls/`; summary JSON files record the selected model, settings, call counts, token usage, test outcomes, coverage, and assertion validation.
