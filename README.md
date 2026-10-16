# Prompt Engineering for Hardware Design

ECEN 689 coursework exploring how language models generate, repair, and verify hardware designs. The work progresses from prompt comparisons for individual RTL blocks, through retrieval-augmented debugging of a single-cycle RV32I processor, to coverage-guided verification of a five-stage pipelined processor.

## Weekly work

The folders follow assignment order; each assignment represents a stage of the project.

| Stage | Topic | Work and evidence |
|---|---|---|
| [Assignment 1](assignment_01_prompt_engineering/) | Prompt engineering for RTL and testbench generation | ALU, register file, immediate extender, and controller; three prompt styles with two runs per block and style; generated RTL, testbenches, and verification records. |
| [Assignment 2](assignment_02_rag_debugging/) | RAG and iterative tool feedback for hardware debugging | Retrieval knowledge base, generation and repair agent, processor integration, seeded bug repairs, ablation experiments, and final processor validation. |
| [Assignment 3](assignment_03_llm_verification/) | LLM-guided verification of a pipelined RV32I processor | Pipeline hazards and redirects, directed program generation, mutation testing, coverage feedback, assertion generation, and final verification evidence. |

## Repository layout

```text
.
├── README.md
├── assignment_01_prompt_engineering/
│   ├── README.md
│   ├── code/                   # Workflow, prompts, specifications, and setup
│   ├── rtl_and_testbenches/     # Selected designs and generated versions
│   └── run_records/             # Prompts, model responses, and verification logs
├── assignment_02_rag_debugging/
│   ├── README.md
│   ├── 837004069_A2_Report.pdf  # Final analysis and plots
│   └── A2_student/
│       ├── agent/              # Generation, feedback, ranking, and repair
│       ├── rag/                # Indexing and retrieval
│       ├── rag_dataset/        # Retrieval documents
│       ├── .rag_index/         # Saved retrieval index
│       ├── rtl/                # Final processor RTL
│       ├── scripts/            # Module and processor verification
│       └── submission_artifacts/
│           ├── task1/          # Index and five sample retrieval queries
│           ├── task2/          # Agent source snapshots and smoke run
│           ├── task3/          # Generation, repairs, and bug reports
│           ├── task4/          # Ablation trials, RTL snapshots, and metrics
│           └── task5/          # Final processor validation transcripts
└── assignment_03_llm_verification/
    ├── README.md
    ├── 837004069_A3_Report.pdf  # Final implementation and verification report
    └── A3_student/
        ├── agent/              # Test, coverage, mutation, and assertion workflows
        ├── core/               # Five-stage processor and reused RTL modules
        ├── harness/            # Supplied simulation and coverage testbenches
        ├── reference/          # RV32I encoders and instruction-set oracle
        ├── results/            # Tests, assertions, coverage, and run records
        └── scripts/            # Task launchers and independent verification
```

## Getting started

Clone the repository, then follow the README for the assignment you want to explore. Run assignment commands from the working directory stated in its README; the repository root is a navigation entry point.

All workflows use Python and Icarus Verilog. Model calls require a configured provider API key. Assignment 2 additionally uses Sentence Transformers and FAISS for retrieval; its environment files list the dependencies. Assignment 3 uses only the Python standard library for its agent and relies on the supplied ISS and Icarus testbenches for acceptance.

For a local check of the saved Assignment 2 processor, with Icarus Verilog and Python available:

```bash
cd assignment_02_rag_debugging/A2_student
bash scripts/run_all_sample.sh
```

This checks the saved RTL without making model calls. Generation and repair commands can replace working RTL, so use a separate working copy when reproducing experiments. Archived logs retain the original run paths and model outputs as evidence.

Assignment 1 contains the original project contents under its topic folder. Assignment 2 reuses those blocks in a single-cycle processor and studies retrieval-assisted repair. Assignment 3 reuses the verified modules in a pipelined processor and shifts the LLM workflow from implementation repair to directed verification, coverage closure, and assertion generation.
