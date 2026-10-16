"""Versioned prompts for Task 2 test generation and mutation-gap repair."""

from __future__ import annotations

import json
from typing import Iterable, List


PROMPT_VERSION = "task2-v1"
COVERAGE_PROMPT_VERSION = "task3-coverage-v2"
ASSERTION_PROMPT_VERSION = "task4-assertions-v1"

SYSTEM_PROMPT = """You are a verification engineer generating short, deterministic RV32I programs for a five-stage pipelined processor. Return only one compact valid JSON object matching the requested schema. Do not show reasoning. Do not use Markdown fences, labels, assembly strings, comments outside JSON, or unsupported instructions. Every targeted behavior must affect the selected signature register so a hardware bug causes an observable mismatch."""

ASSERTION_SYSTEM_PROMPT = """You are a hardware verification engineer writing an Icarus-compatible SystemVerilog assertion module. Return only the complete module source from module through endmodule. Do not use Markdown fences or explanatory text. Preserve the supplied module name, port names, port order, widths, and directions exactly. Use immediate assertions inside always @(posedge clk), guarded by if (!reset)."""

INSTRUCTION_FORMAT = """
Represent each instruction as {"op":"NAME","args":[integers]}.
Allowed forms and argument order:
- ADD/SUB/SLL/SLT/SLTU/XOR/SRL/SRA/OR/AND: [rd, rs1, rs2]
- ADDI/SLTI/SLTIU/XORI/ORI/ANDI: [rd, rs1, signed_12_bit_imm]
- SLLI/SRLI/SRAI: [rd, rs1, shamt_0_to_31]
- LB/LH/LW/LBU/LHU: [rd, base_rs1, signed_12_bit_offset]
- SB/SH/SW: [base_rs1, value_rs2, signed_12_bit_offset]
- BEQ/BNE/BLT/BGE/BLTU/BGEU: [rs1, rs2, signed_even_PC_relative_byte_offset]
- LUI/AUIPC: [rd, immediate_with_low_12_bits_zero]
- JAL: [rd, signed_even_PC_relative_byte_offset]
- JALR: [rd, base_rs1, signed_12_bit_offset]

Offsets are relative to the current instruction PC. Instructions are four bytes each. Use numeric register indices 0-31. Reserve x31: the agent automatically appends LUI/ADDI/SW instructions using x31 to store signature_reg to address 0x100. Do not include that signature store yourself. Programs start with zeroed registers and zeroed data memory. Keep each body below 30 instructions and ensure control flow reaches the appended epilogue.
"""

OUTPUT_SCHEMA = """
Return exactly this schema for every response:
{
  "tests": [
    {
      "name": "lowercase_snake_case_name",
      "target_family": "forwarding",
      "description": "one sentence explaining the observable failure",
      "signature_reg": 1,
      "instructions": [{"op":"ADDI","args":[1,0,5]}]
    }
  ]
}
The required array key is "instructions". Never use "body", "program", or assembly text.
"""


def initial_test_prompt() -> str:
    return f"""Generate 10-14 independent directed test programs. Cover every target_family below with at least two tests where practical.

1. forwarding: source A and source B, Memory and Writeback distances, plus two in-flight writers to the same register so Memory must beat Writeback.
2. x0_integrity: attempt a nonzero write to x0 and immediately consume x0 through each operand position.
3. load_use: a load immediately followed by an rs1 consumer and a separate rs2 consumer; initialize memory first.
4. flush_redirect: taken branch, JAL, and JALR tests where a wrong-path instruction would corrupt the eventual signature; also include an untaken branch.
5. branch_jump_target: varied branch/JAL offsets and a JALR with an odd raw target whose required bit-zero clearing becomes observable through a PC-derived result or link.

Each program must make the targeted hazard change signature_reg. Avoid tests that merely execute the instruction without propagating its result. Use distinct lowercase snake_case names. Valid target_family values are forwarding, x0_integrity, load_use, flush_redirect, and branch_jump_target.

{OUTPUT_SCHEMA}
{INSTRUCTION_FORMAT}"""


def repair_prompt(previous_errors: Iterable[str], missed_families: Iterable[str]) -> str:
    errors = list(previous_errors)
    families = sorted(set(missed_families))
    return f"""Generate 2-4 replacement or additional directed tests for each listed missed family. If the list is empty, generate 2-4 corrected tests addressing the validation problems.

Missed mutation families:
{json.dumps(families, indent=2)}

Validation problems from the previous response/run:
{json.dumps(errors[-20:], indent=2)}

Make the corrupted behavior flow directly into signature_reg. Use new lowercase snake_case names.

{OUTPUT_SCHEMA}
{INSTRUCTION_FORMAT}"""


def coverage_feedback_prompt(
    missing_bins: Iterable[str],
    hit_bins: Iterable[str],
    existing_test_evidence: Iterable[dict],
    previous_outcomes: Iterable[str],
) -> str:
    """Ask for small additions aimed only at measured coverage holes."""
    coverage_schema = OUTPUT_SCHEMA.replace(
        '"target_family": "forwarding"', '"target_family": "coverage"'
    )
    evidence = [
        {
            "name": record.get("name"),
            "status": record.get("status"),
            "coverage_bins": record.get("coverage_bins", []),
        }
        for record in existing_test_evidence
    ]
    return f"""Analyze the measured coverage of an existing RV32I verification suite, then generate only the additional directed tests needed to close its uncovered bins. You are extending the existing suite; do not recreate or replace tests that already provide coverage.

Existing passing tests and the coverage bins observed for each test:
{json.dumps(evidence, indent=2)}

Current cumulative coverage is {len(set(hit_bins))}/{len(set(hit_bins)) + len(set(missing_bins))} bins.

Missing bins measured by the instrumented RTL testbench:
{json.dumps(sorted(set(missing_bins)), indent=2)}

Bins already hit by passing tests:
{json.dumps(sorted(set(hit_bins)), indent=2)}

Outcomes from earlier coverage-feedback attempts, if any:
{json.dumps(list(previous_outcomes)[-20:], indent=2)}

The fixed coverage bins are:
- instruction groups: OP_REG, OP_IMM, OP_LOAD, OP_STORE, OP_BRANCH, OP_JAL, OP_JALR, OP_LUI, OP_AUIPC
- hazards: fwdA_mem, fwdA_wb, fwdB_mem, fwdB_wb, no_forward, load_use_stall, flush
- control paths: branch_taken, branch_not_taken, jal, jalr, no_control

First use the evidence above to determine why the existing tests miss the listed bins. Return 1-3 minimal targeted additions that cover those missing bins without duplicating existing tests. Use target_family "coverage". Each requested instruction-group bin must execute in the body of a program that reaches the signature store. Propagate the targeted instruction's result into signature_reg so the test checks useful behavior. For OP_AUIPC, execute AUIPC and use its PC-relative result in the final signature. For forwarding bins, arrange producer/consumer distances deliberately. For control bins, make the redirect or branch outcome affect the signature. Use new lowercase snake_case names that identify the missing bin. Return only the requested JSON; do not include your analysis.

{coverage_schema}
{INSTRUCTION_FORMAT}"""


def assertion_generation_prompt(template: str, specification: str) -> str:
    return f"""Generate results/assertions.sv from the supplied template and invariant specification.

Requirements:
- Keep exactly the template module name and port interface.
- Use immediate assert (<condition>) else $display(...) statements inside always @(posedge clk).
- Guard every assertion with if (!reset).
- Do not use assert property, property, assume, bind, interfaces, packages, delays, or unavailable internal signals.
- Implement both operands separately.
- Emit exactly these eight stable failure names, each beginning with ASSERT_FAIL:
  1. x0_read_rs1_zero
  2. x0_read_rs2_zero
  3. no_forward_x0_rs1
  4. no_forward_x0_rs2
  5. forward_a_mem_has_producer
  6. forward_a_wb_has_producer
  7. forward_b_mem_has_producer
  8. forward_b_wb_has_producer
- Each forwarding assertion must express the required implication: when its select value is active, the corresponding stage must have RegWrite enabled, a matching source/destination register, and a nonzero destination.
- Implement only the eight required assertions; unsupported optional checks can create false positives.
- Return only compilable SystemVerilog source.

Supplied template:
--- TEMPLATE START ---
{template}
--- TEMPLATE END ---

Required invariant specification:
--- SPECIFICATION START ---
{specification}
--- SPECIFICATION END ---"""
def assertion_repair_prompt(
    template: str,
    specification: str,
    previous_source: str,
    validation_errors: Iterable[str],
) -> str:
    return f"""Repair the candidate SystemVerilog assertion module using the validation evidence below. Return a complete replacement module, not a patch.

Validation errors or false positives:
{json.dumps(list(validation_errors)[-30:], indent=2)}

Previous candidate:
--- CANDIDATE START ---
{previous_source}
--- CANDIDATE END ---

Preserve exactly the supplied interface and implement the eight named required invariants with immediate assertions inside always @(posedge clk), guarded by if (!reset). Every failure message must begin with ASSERT_FAIL followed by its required stable name. Do not use assert property or add optional assertions.

Supplied template:
--- TEMPLATE START ---
{template}
--- TEMPLATE END ---

Required invariant specification:
--- SPECIFICATION START ---
{specification}
--- SPECIFICATION END ---"""
