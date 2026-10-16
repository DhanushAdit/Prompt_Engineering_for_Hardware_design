"""Extraction and behavioral validation for LLM-generated Task 4 assertions."""

from __future__ import annotations

import re
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, List


EXPECTED_PORTS = [
    "clk", "reset", "Rs1D", "Rs2D", "rd1D", "rd2D", "ForwardAE", "ForwardBE",
    "Rs1E", "Rs2E", "RegWriteM", "RdM", "RegWriteW", "RdW",
]

REQUIRED_ASSERTIONS = [
    "x0_read_rs1_zero",
    "x0_read_rs2_zero",
    "no_forward_x0_rs1",
    "no_forward_x0_rs2",
    "forward_a_mem_has_producer",
    "forward_a_wb_has_producer",
    "forward_b_mem_has_producer",
    "forward_b_wb_has_producer",
]


def extract_assertion_module(text: str) -> str:
    """Extract one complete student_assertions module from a model response."""
    start_match = re.search(r"\bmodule\s+student_assertions\b", text)
    if not start_match:
        raise ValueError("response does not contain module student_assertions")
    end_match = re.search(r"\bendmodule\b", text[start_match.start():])
    if not end_match:
        raise ValueError("student_assertions has no endmodule")
    end = start_match.start() + end_match.end()
    return text[start_match.start():end].strip() + "\n"


def _without_comments(source: str) -> str:
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    return re.sub(r"//.*", "", source)


def validate_assertion_source(source: str) -> List[str]:
    """Check the fixed interface and required immediate-assertion structure."""
    errors: List[str] = []
    clean = _without_comments(source)
    header = re.search(
        r"\bmodule\s+student_assertions\s*\((.*?)\)\s*;",
        clean,
        flags=re.DOTALL,
    )
    if not header:
        return ["module student_assertions must use the supplied ANSI-style port list"]
    ports = []
    for declaration in header.group(1).split(","):
        identifiers = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", declaration)
        if identifiers:
            ports.append(identifiers[-1])
    if ports != EXPECTED_PORTS:
        errors.append(f"ports must exactly match the template order {EXPECTED_PORTS}; found {ports}")
    if re.search(r"\bassert\s+property\b", clean):
        errors.append("concurrent 'assert property' is unsupported; use immediate assert (...)")
    if len(re.findall(r"\bassert\s*\(", clean)) < len(REQUIRED_ASSERTIONS):
        errors.append(f"at least {len(REQUIRED_ASSERTIONS)} immediate assertions are required")
    if not re.search(r"\balways\s*@\s*\(\s*posedge\s+clk\s*\)", clean):
        errors.append("assertions must be inside always @(posedge clk)")
    if not re.search(r"\bif\s*\(\s*!\s*reset\s*\)", clean):
        errors.append("clocked assertions must be guarded by if (!reset)")
    for name in REQUIRED_ASSERTIONS:
        if not re.search(
            rf"\$display\s*\(\s*\"ASSERT_FAIL\s+{re.escape(name)}(?:\s|\")",
            clean,
        ):
            errors.append(f"missing required failure report: ASSERT_FAIL {name}")
    return errors


PROBE_TESTBENCH = r"""`timescale 1ns/1ps
module assertion_probe_tb;
    logic clk = 0;
    logic reset = 1;
    logic [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdM, RdW;
    logic [31:0] rd1D, rd2D;
    logic [1:0] ForwardAE, ForwardBE;
    logic RegWriteM, RegWriteW;

    student_assertions dut(
        .clk(clk), .reset(reset),
        .Rs1D(Rs1D), .Rs2D(Rs2D), .rd1D(rd1D), .rd2D(rd2D),
        .ForwardAE(ForwardAE), .ForwardBE(ForwardBE), .Rs1E(Rs1E), .Rs2E(Rs2E),
        .RegWriteM(RegWriteM), .RdM(RdM), .RegWriteW(RegWriteW), .RdW(RdW)
    );

    always #5 clk = ~clk;

    task automatic clean_inputs;
        begin
            Rs1D = 5'd1; Rs2D = 5'd2; rd1D = 32'd0; rd2D = 32'd0;
            ForwardAE = 2'b00; ForwardBE = 2'b00; Rs1E = 5'd1; Rs2E = 5'd2;
            RegWriteM = 1'b0; RdM = 5'd0; RegWriteW = 1'b0; RdW = 5'd0;
        end
    endtask

    task automatic sample_violation;
        begin
            @(posedge clk); #1;
        end
    endtask

    initial begin
        clean_inputs();
        repeat (2) @(posedge clk);
        @(negedge clk); reset = 0;

        @(negedge clk); clean_inputs(); Rs1D = 0; rd1D = 32'h1;
        $display("PROBE_CASE x0_read_rs1_zero"); sample_violation(); $display("PROBE_END");
        @(negedge clk); clean_inputs(); Rs2D = 0; rd2D = 32'h1;
        $display("PROBE_CASE x0_read_rs2_zero"); sample_violation(); $display("PROBE_END");
        @(negedge clk); clean_inputs(); Rs1E = 0; ForwardAE = 2'b10;
        $display("PROBE_CASE no_forward_x0_rs1"); sample_violation(); $display("PROBE_END");
        @(negedge clk); clean_inputs(); Rs2E = 0; ForwardBE = 2'b10;
        $display("PROBE_CASE no_forward_x0_rs2"); sample_violation(); $display("PROBE_END");
        @(negedge clk); clean_inputs(); Rs1E = 5; ForwardAE = 2'b10; RdM = 5;
        $display("PROBE_CASE forward_a_mem_has_producer"); sample_violation(); $display("PROBE_END");
        @(negedge clk); clean_inputs(); Rs1E = 5; ForwardAE = 2'b01; RdW = 5;
        $display("PROBE_CASE forward_a_wb_has_producer"); sample_violation(); $display("PROBE_END");
        @(negedge clk); clean_inputs(); Rs2E = 6; ForwardBE = 2'b10; RdM = 6;
        $display("PROBE_CASE forward_b_mem_has_producer"); sample_violation(); $display("PROBE_END");
        @(negedge clk); clean_inputs(); Rs2E = 6; ForwardBE = 2'b01; RdW = 6;
        $display("PROBE_CASE forward_b_wb_has_producer"); sample_violation(); $display("PROBE_END");

        @(negedge clk); clean_inputs();
        $finish;
    end
endmodule
"""


def run_activation_probe(assertion_file: Path) -> Dict[str, Any]:
    """Intentionally violate every required invariant and confirm each one fires."""
    with tempfile.TemporaryDirectory(prefix="a3-assertion-probe-") as temporary:
        work = Path(temporary)
        testbench = work / "assertion_probe_tb.sv"
        executable = work / "probe.vvp"
        testbench.write_text(PROBE_TESTBENCH, encoding="utf-8")
        command = [
            "iverilog", "-g2012", "-s", "assertion_probe_tb", "-o", str(executable),
            str(testbench), str(assertion_file),
        ]
        try:
            compiled = subprocess.run(command, capture_output=True, text=True, timeout=120)
        except FileNotFoundError:
            return {"status": "tool_missing", "error": "iverilog was not found on PATH"}
        except subprocess.TimeoutExpired:
            return {"status": "compile_timeout", "command": command}
        compile_output = compiled.stdout + compiled.stderr
        if compiled.returncode != 0:
            return {
                "status": "compile_error", "command": command,
                "returncode": compiled.returncode, "output": compile_output,
            }
        try:
            completed = subprocess.run(
                ["vvp", str(executable)], capture_output=True, text=True, timeout=30
            )
        except (FileNotFoundError, subprocess.TimeoutExpired) as error:
            return {"status": "run_error", "error": str(error)}
        output = completed.stdout + completed.stderr
        fired = sorted(set(re.findall(
            r"^ASSERT_FAIL\s+([A-Za-z_][A-Za-z0-9_]*)", output, flags=re.MULTILINE
        )))
        case_results = {}
        for name, case_output in re.findall(
            r"PROBE_CASE\s+([A-Za-z_][A-Za-z0-9_]*)\s*\n(.*?)PROBE_END",
            output,
            flags=re.DOTALL,
        ):
            case_firings = sorted(set(re.findall(
                r"^ASSERT_FAIL\s+([A-Za-z_][A-Za-z0-9_]*)",
                case_output,
                flags=re.MULTILINE,
            )))
            case_results[name] = {
                "fired": case_firings,
                "expected_fired": name in case_firings,
            }
        missing = sorted(
            name for name in REQUIRED_ASSERTIONS
            if not case_results.get(name, {}).get("expected_fired", False)
        )
        return {
            "status": "pass" if not missing else "missing_assertion_firings",
            "fired": fired,
            "missing": missing,
            "case_results": case_results,
            "returncode": completed.returncode,
            "output": output,
        }
