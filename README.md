# Prompt Engineering for Hardware Design

ECEN 689 coursework exploring how language models generate and repair hardware designs. The work progresses from comparing prompting strategies for individual RTL blocks to retrieval-augmented debugging of a single-cycle RV32I processor.

## Weekly work

The folders follow assignment order; each assignment represents a stage of the project.

| Stage | Topic | Work and evidence |
|---|---|---|
| [Assignment 1](assignment_01_prompt_engineering/) | Prompt engineering for RTL and testbench generation | ALU, register file, immediate extender, and controller; three prompt styles with two runs per block and style; generated RTL, testbenches, and verification records. |
| [Assignment 2](assignment_02_rag_debugging/) | RAG and iterative tool feedback for hardware debugging | Retrieval knowledge base, generation and repair agent, processor integration, seeded bug repairs, ablation experiments, and final processor validation. |

## Repository layout

```text
.
├── README.md
├── assignment_01_prompt_engineering/
│   ├── README.md
│   ├── code/                   # Workflow, prompts, specifications, and setup
│   ├── rtl_and_testbenches/     # Selected designs and generated versions
│   └── run_records/             # Prompts, model responses, and verification logs
└── assignment_02_rag_debugging/
    ├── README.md
    ├── 837004069_A2_Report.pdf  # Final analysis and plots
    └── A2_student/
        ├── agent/              # Generation, feedback, ranking, and repair
        ├── rag/                # Indexing and retrieval
        ├── rag_dataset/        # Retrieval documents
        ├── .rag_index/         # Saved retrieval index
        ├── rtl/                # Final processor RTL
        ├── scripts/            # Module and processor verification
        └── submission_artifacts/
            ├── task1/          # Index and five sample retrieval queries
            ├── task2/          # Agent source snapshots and smoke run
            ├── task3/          # Generation, repairs, and bug reports
            ├── task4/          # Ablation trials, RTL snapshots, and metrics
            └── task5/          # Final processor validation transcripts
```

## Getting started

Clone the repository, then follow the README for the assignment you want to explore. Run assignment commands from the working directory stated in its README; the repository root is a navigation entry point.

Both workflows use Python and Icarus Verilog. Model calls require a configured provider API key. Assignment 2 additionally uses Sentence Transformers and FAISS for retrieval; its environment files list the dependencies.

For a local check of the saved Assignment 2 processor, with Icarus Verilog and Python available:

```bash
cd assignment_02_rag_debugging/A2_student
bash scripts/run_all_sample.sh
```

This checks the saved RTL without making model calls. Generation and repair commands can replace working RTL, so use a separate working copy when reproducing experiments. Archived logs retain the original run paths and model outputs as evidence.

Assignment 1 contains the original project contents, preserved under its topic folder. Assignment 2 builds on that work by reusing the earlier processor blocks. Future assignments can be added as separate numbered topic folders with an entry in the table above.
