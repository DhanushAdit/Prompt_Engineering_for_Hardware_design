# ECEN 689: Assignment 1 (RTL & Testbench Agent)

This folder is the Assignment 1 student package.

**Start with the two handouts** (provided with the course materials):
- **Course Setup Guide** — one-time environment + API key setup (Python/conda, Icarus, `.env`).
- **Assignment 1 handout** — the assignment itself: model to use, the five tasks, and grading.

Quick start once you've done the setup in those handouts:

```bash
bash check_setup.sh                                   # preflight: checks Python, Icarus, specs, API key
python student_code/lab1.py --spec specs/alu.yaml --out-dir results/alu   # run the workflow on a module
python student_code/lab1.py --spec specs/alu.yaml --smoke-test            # add --smoke-test to check the LLM client works
```

Contents:
- `specs/`: the four module specifications
- `student_code/`: the workflow you implement (`lab1.py`) plus provided utilities
- `module_packages/`: per-module sample testbenches, sample vectors, and run scripts
- `tamu_ai_chat/`: the LLM API client (used for the TAMU AI Chat provider)
- `environment.yml`, `requirements.txt`: Python environment / packages
- `env.example`: copy to `.env` and add ONE API key
- `scripts/install_icarus.sh`: fallback Icarus Verilog installer
- `run_generated_tb.sh`: run YOUR generated testbench against YOUR generated RTL (Task 4 self-check)
- `check_setup.sh`: preflight setup checker
