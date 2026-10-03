#!/usr/bin/env bash
# Task 4 Part B: three seeded datapath trials per arm, retaining every result.
set -euo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$R"
PYTHON_BIN="${A2_PYTHON:-python}"
OUT="ablation_experiment/seeded"
if [[ -e "$OUT" ]]; then
    echo "Refusing to overwrite existing seeded experiment: $OUT" >&2
    exit 2
fi
for module in alu regfile extend controller pc_unit branch_unit memory_access; do
    test -f "rtl/$module.sv"
done
test -f bugs/datapath_buggy.sv
test -f .rag_index/vectors.faiss
mkdir -p "$OUT/rag" "$OUT/rag_feedback" "$OUT/inputs/rtl"
cp rtl/*.sv "$OUT/inputs/rtl/"
cp bugs/datapath_buggy.sv "$OUT/inputs/"
cp .rag_index/metadata.json "$OUT/inputs/index_metadata.json"
sha256sum rtl/*.sv bugs/datapath_buggy.sv .rag_index/* agent/*.py rag/*.py scripts/*.sh testbench/*.sv > "$OUT/inputs/source_sha256.txt"
date --iso-8601=seconds > "$OUT/started_at.txt"
"$PYTHON_BIN" --version > "$OUT/python_version.txt" 2>&1
initial_datapath=0
if [[ -f rtl/datapath.sv ]]; then
    initial_datapath=1
fi
restore_initial() {
    if [[ "$initial_datapath" -eq 1 ]]; then
        cp "$OUT/inputs/rtl/datapath.sv" rtl/datapath.sv
    elif [[ -f rtl/datapath.sv ]]; then
        # Preserve an interrupted/unarchived candidate rather than deleting it.
        mv rtl/datapath.sv "$OUT/interrupted_datapath.sv"
    fi
}
trap restore_initial EXIT
for arm in rag rag_feedback; do
    for trial in 1 2 3; do
        stem="$OUT/$arm/ablation_${arm}_${trial}"
        echo "Starting seeded arm=$arm trial=$trial"
        set +e
        HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 PYTHONUNBUFFERED=1 \
            timeout 900 "$PYTHON_BIN" agent/run_debug_agent.py \
            --module datapath --arm "$arm" --provider tamu --model gpt-5.4 \
            --seed-rtl bugs/datapath_buggy.sv --log-file "$stem.json" \
            > "$stem.terminal.txt" 2>&1
        rc=$?
        set -e
        printf '%s\n' "$rc" > "$stem.exit_code.txt"
        if [[ -f rtl/datapath.sv ]]; then
            mv rtl/datapath.sv "$OUT/$arm/datapath_${trial}.sv"
        fi
        echo "Finished seeded arm=$arm trial=$trial exit=$rc"
        if [[ ! -f "$stem.json" ]]; then
            echo "Run did not write JSON; inspect $stem.terminal.txt before continuing." >&2
            exit 2
        fi
    done
done
date --iso-8601=seconds > "$OUT/finished_at.txt"
