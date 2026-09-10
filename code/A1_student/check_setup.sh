#!/usr/bin/env bash
# check_setup.sh: preflight for Assignment 1 - verifies Python, packages, Icarus (+SV features),
# check_setup.sh: the specs/workflow, and that an LLM API key is visible. Run from the package root.
# check_setup.sh: usage: bash check_setup.sh   (does NOT call the LLM API; it only checks the key is set)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
PASS=0; FAIL=0
ok(){ echo "  [ OK ] $1"; PASS=$((PASS+1)); }
bad(){ echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

echo "== Assignment 1 setup check =="

# 1) Python 3.10+
if command -v python >/dev/null 2>&1; then PY=python; elif command -v python3 >/dev/null 2>&1; then PY=python3; else PY=""; fi
if [ -n "$PY" ] && "$PY" -c 'import sys; raise SystemExit(0 if sys.version_info>=(3,10) else 1)'; then
    ok "Python $("$PY" -V 2>&1 | awk '{print $2}') (3.10+)"
else
    bad "Python 3.10+ not found (create the conda env: conda env create -f environment.yml && conda activate ecen689-a1)"
fi

# 2) PyYAML
if [ -n "$PY" ] && "$PY" -c 'import yaml' 2>/dev/null; then ok "PyYAML importable"
else bad "PyYAML missing (pip install -r requirements.txt, or activate the conda env)"; fi

# 3) Icarus present
if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
    ok "iverilog + vvp on PATH ($(iverilog -V 2>/dev/null | head -1))"
    # 3b) SystemVerilog features the modules use actually compile under -g2012
    TMP="$(mktemp -d)"
    cat > "$TMP/feat.sv" <<'SV'
`timescale 1ns/1ps
module feat_tb;
  logic [31:0] a; logic [4:0] sh; logic [31:0] r; logic sub;
  logic signed [31:0] as; assign as = a;
  always_comb begin
    unique case (sub)
      1'b1: r = $unsigned($signed(a) >>> sh);
      default: r = a << sh[4:0];
    endcase
  end
  initial begin a=32'h80000000; sh=1; sub=1; #1;
    if (r===32'hC0000000) $display("PASS"); else $display("FAIL got %08x", r);
    $finish; end
endmodule
SV
    if iverilog -g2012 -o "$TMP/feat.vvp" "$TMP/feat.sv" >/dev/null 2>&1 && \
       vvp "$TMP/feat.vvp" 2>/dev/null | grep -q '^PASS$'; then
        ok "Icarus handles the required SystemVerilog ( \$signed / >>> / always_comb / unique case )"
    else
        bad "Icarus did not correctly handle required SystemVerilog - upgrade to v11+ (see the handout)"
    fi
    rm -rf "$TMP"
else
    bad "iverilog/vvp not found (install per the handout, or: bash scripts/install_icarus.sh; source ~/.bashrc)"
fi

# 4) specs + workflow load
if [ -n "$PY" ] && "$PY" -c "import sys; sys.path.insert(0,'student_code'); from io_utils import load_spec; [load_spec('specs/%s.yaml'%m) for m in ('alu','regfile','extend','controller')]" 2>/dev/null; then
    ok "all four specs load"
else bad "could not load specs/*.yaml (run from the package root)"; fi
if [ -n "$PY" ] && "$PY" student_code/lab1.py --help >/dev/null 2>&1; then ok "lab1.py runs"; else bad "lab1.py --help failed"; fi

# 5) an API key is visible (env or .env) - we do NOT call the API here
if [ -n "$PY" ] && "$PY" -c "import sys; sys.path.insert(0,'student_code'); import llm_clients, os; raise SystemExit(0 if (os.getenv('TAMUS_AI_CHAT_API_KEY') or os.getenv('OPENAI_API_KEY')) else 1)" 2>/dev/null; then
    ok "an LLM API key is set (TAMU or OpenAI)"
else
    bad "no API key found - put one in a .env file (cp env.example .env) or export it"
fi

echo "== result: $PASS passed, $FAIL failed =="
[ "$FAIL" -eq 0 ] && echo "Setup looks good - you can start the assignment." || echo "Fix the [FAIL] items above (see the handout Environment Setup)."
exit $([ "$FAIL" -eq 0 ] && echo 0 || echo 1)
