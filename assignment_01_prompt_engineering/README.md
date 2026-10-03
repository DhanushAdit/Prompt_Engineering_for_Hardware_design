# Assignment 1: Prompt Engineering for RTL and Testbench Generation

[Back to the project overview](../README.md)

## Overview

This repository explores prompt strategies for generating SystemVerilog RTL
and self-checking testbenches with an LLM. Phase 1 covers four hardware blocks:

- ALU
- Register file
- Immediate extender
- Controller

Each block is generated with three prompt styles, two independent runs per
style, and bounded verification-driven repair.

## Approach

The workflow has three stages:

1. **Phase A - RTL generation:** read the YAML specification and ask the model
   for a complete SystemVerilog implementation.
2. **Phase B - Testbench generation:** ask the model for an independent,
   self-checking testbench with reference behavior and meaningful coverage.
3. **Phase C - Repair and validation:** compile the RTL, run the instructor
   sample tests, and provide diagnostics to the model only when a repair is
   needed. The testbench is repaired only after the RTL passes the instructor
   tests.

The three prompt styles are `direct`, `rules_constraints`, and `template_fill`.
The formal experiment contains 4 blocks x 3 styles x 2 runs = 24 initial
generation runs. Final RTL/testbench pairs are retained after passing both
instructor tests and the generated testbench.

## Repository Structure

```text
.
|-- README.md
|-- code/
|   |-- run_experiment.py       Runs the 24-run experiment
|   |-- prompt_templates/       Prompt styles and RTL guidance
|   `-- A1_student/             Reproducible workflow and specifications
|-- rtl_and_testbenches/
|   |-- final/                  Selected RTL and testbenches
|   `-- versions/               Generated versions and repair history
`-- run_records/                Prompts, responses, logs, scores, and checks
```

## Reproduction

Use the provided conda environment or another Python 3.10+ environment with
PyYAML installed.

```bash
cd assignment_01_prompt_engineering  # from the repository root
conda activate ecen689-a1
python3 -m pip install -r code/A1_student/requirements.txt
bash code/A1_student/check_setup.sh
export TAMUS_AI_CHAT_API_KEY="your_key_here"
```

The setup check does not call the API. It verifies Python, PyYAML, Icarus
Verilog, the packaged specifications, the workflow, and API-key visibility.

Run the complete experiment with:

```bash
python3 code/run_experiment.py \
  --output run_records/reproduction_001 \
  --provider tamu
```

Use a new output directory for every new experiment. To run one block and one
prompt style directly:

```bash
A1_PROMPT_STYLE=direct python3 code/A1_student/student_code/lab1.py \
  --spec code/A1_student/specs/alu.yaml \
  --out-dir run_records/single_alu \
  --provider tamu
```

Replace `alu` with `regfile`, `extend`, or `controller`. Valid prompt styles
are `direct`, `rules_constraints`, and `template_fill`.

## Notes

This phase focuses on comparing prompt styles and building a repeatable
generation, verification, and repair loop. Detailed prompts, model responses,
diagnostics, and validation records are retained under `run_records/`.
API keys are intentionally not included in this repository.
