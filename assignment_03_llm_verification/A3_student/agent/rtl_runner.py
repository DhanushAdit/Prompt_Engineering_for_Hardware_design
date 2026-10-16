"""Compile a selected core directory and compare programs with the reference ISS."""

from __future__ import annotations

import subprocess
import tempfile
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

from test_programs import TestProgram


ROOT = Path(__file__).resolve().parents[1]
CORE_TB = ROOT / "harness" / "core_tb.sv"
COVERAGE_TB = ROOT / "harness" / "core_tb_cov.sv"
ASSERTION_TB = ROOT / "harness" / "core_tb_assert.sv"

INSTRUCTION_BINS = {
    "0110011": "OP_REG", "0010011": "OP_IMM", "0000011": "OP_LOAD",
    "0100011": "OP_STORE", "1100011": "OP_BRANCH", "1101111": "OP_JAL",
    "1100111": "OP_JALR", "0110111": "OP_LUI", "0010111": "OP_AUIPC",
}
HAZARD_BINS = {
    "fwdA_mem", "fwdA_wb", "fwdB_mem", "fwdB_wb", "no_forward",
    "load_use_stall", "flush",
}
CONTROL_BINS = {"branch_taken", "branch_not_taken", "jal", "jalr", "no_control"}
ALL_COVERAGE_BINS = set(INSTRUCTION_BINS.values()) | HAZARD_BINS | CONTROL_BINS
COVERAGE_RE = re.compile(
    r"COV op=([01]{7}) f3=[01]{3} fwdA=([01]{2}) fwdB=([01]{2}) "
    r"stall=(\d) flush=(\d) branchE=(\d) pcsrc=(\d) jump=(\d)"
)


@dataclass
class CoreSources:
    directory: Path
    datapath: Path
    submodules: List[Path]


def discover_core(core_directory: Path) -> CoreSources:
    core_directory = Path(core_directory).expanduser().resolve()
    if not core_directory.is_dir():
        raise ValueError(f"--core must be a directory: {core_directory}")
    datapath = core_directory / "datapath_pipelined.sv"
    if not datapath.is_file():
        matches = sorted(core_directory.rglob("datapath_pipelined.sv"))
        if len(matches) != 1:
            raise ValueError(
                f"expected exactly one datapath_pipelined.sv under {core_directory}; found {len(matches)}"
            )
        datapath = matches[0]
    submodule_directory = datapath.parent / "submodules"
    if submodule_directory.is_dir():
        submodules = sorted(submodule_directory.glob("*.sv"))
    else:
        submodules = sorted(path for path in datapath.parent.glob("*.sv") if path != datapath)
    if not submodules:
        raise ValueError(f"no SystemVerilog submodules found under {core_directory}")
    return CoreSources(core_directory, datapath, submodules)


def compile_core(
    core_directory: Path,
    build_directory: Path,
    testbench: Path = CORE_TB,
    top_module: str = "core_tb",
    extra_sources: Iterable[Path] = (),
) -> Tuple[Optional[Path], Dict[str, Any]]:
    try:
        sources = discover_core(core_directory)
    except ValueError as error:
        return None, {"status": "configuration_error", "error": str(error)}
    executable = build_directory / "core.vvp"
    command = [
        "iverilog", "-g2012", "-s", top_module, "-o", str(executable),
        str(testbench), *[str(path) for path in extra_sources],
        str(sources.datapath), *[str(path) for path in sources.submodules],
    ]
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=120)
    except FileNotFoundError:
        return None, {"status": "tool_missing", "error": "iverilog was not found on PATH", "command": command}
    except subprocess.TimeoutExpired:
        return None, {"status": "compile_timeout", "error": "iverilog exceeded 120 seconds", "command": command}
    output = completed.stdout + completed.stderr
    record = {
        "status": "pass" if completed.returncode == 0 else "compile_error",
        "returncode": completed.returncode,
        "command": command,
        "output": output,
        "datapath": str(sources.datapath),
        "submodules": [str(path) for path in sources.submodules],
    }
    return (executable if completed.returncode == 0 else None), record


def run_test(executable: Path, test: TestProgram, work_directory: Path) -> Dict[str, Any]:
    hex_path = work_directory / f"{test.name}.hex"
    hex_path.write_text("".join(f"{word:08x}\n" for word in test.words), encoding="utf-8")
    command = [
        "vvp", str(executable), f"+PROGRAM={hex_path}",
        f"+EXPECT={test.expected_signature:08x}", "+MAX_CYCLES=6000",
    ]
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=60)
    except FileNotFoundError:
        return {"name": test.name, "status": "tool_missing", "error": "vvp was not found on PATH"}
    except subprocess.TimeoutExpired:
        return {"name": test.name, "status": "timeout", "expected_signature": f"0x{test.expected_signature:08x}"}
    output = completed.stdout + completed.stderr
    pass_line = next((line.strip() for line in output.splitlines() if line.strip().startswith("PASS")), "")
    fail_line = next((line.strip() for line in output.splitlines() if line.strip().startswith("FAIL")), "")
    status = "pass" if pass_line else "fail"
    return {
        "name": test.name,
        "target_family": test.target_family,
        "status": status,
        "expected_signature": f"0x{test.expected_signature:08x}",
        "returncode": completed.returncode,
        "verdict": pass_line or fail_line or "no PASS/FAIL verdict",
        "output": output,
    }


def run_suite(core_directory: Path, tests: Iterable[TestProgram]) -> Dict[str, Any]:
    tests = list(tests)
    with tempfile.TemporaryDirectory(prefix="a3-agent-") as temporary:
        work_directory = Path(temporary)
        executable, compile_record = compile_core(core_directory, work_directory)
        if executable is None:
            return {"compile": compile_record, "tests": [], "passed": 0, "failed": len(tests)}
        records = [run_test(executable, test, work_directory) for test in tests]
    passed = sum(record["status"] == "pass" for record in records)
    return {
        "compile": compile_record,
        "tests": records,
        "passed": passed,
        "failed": len(records) - passed,
    }


def coverage_bins(output: str) -> List[str]:
    """Parse the supplied coverage trace using the same rules as harness/run.py."""
    hit = set()
    for match in COVERAGE_RE.finditer(output):
        opcode, forward_a, forward_b, stall, flush, branch, pc_source, jump = match.groups()
        if opcode in INSTRUCTION_BINS:
            hit.add(INSTRUCTION_BINS[opcode])
        if forward_a == "10":
            hit.add("fwdA_mem")
        if forward_a == "01":
            hit.add("fwdA_wb")
        if forward_b == "10":
            hit.add("fwdB_mem")
        if forward_b == "01":
            hit.add("fwdB_wb")
        if forward_a == "00" and forward_b == "00":
            hit.add("no_forward")
        if stall == "1":
            hit.add("load_use_stall")
        if flush == "1":
            hit.add("flush")
        if jump == "1":
            hit.add("jalr" if opcode == "1100111" else "jal")
        elif branch == "1":
            hit.add("branch_taken" if pc_source == "1" else "branch_not_taken")
        else:
            hit.add("no_control")
    return sorted(hit)


def run_coverage_suite(core_directory: Path, tests: Iterable[TestProgram]) -> Dict[str, Any]:
    """Run the suite with coverage instrumentation; failed tests contribute no bins."""
    tests = list(tests)
    with tempfile.TemporaryDirectory(prefix="a3-coverage-") as temporary:
        work_directory = Path(temporary)
        executable, compile_record = compile_core(
            core_directory, work_directory, COVERAGE_TB, "core_tb_cov"
        )
        if executable is None:
            return {
                "compile": compile_record,
                "tests": [],
                "passed": 0,
                "failed": len(tests),
                "hit": [],
                "missed": sorted(ALL_COVERAGE_BINS),
            }
        records = []
        suite_hit = set()
        for test in tests:
            record = run_test(executable, test, work_directory)
            bins = coverage_bins(record.get("output", "")) if record["status"] == "pass" else []
            record["coverage_bins"] = bins
            record.pop("output", None)
            records.append(record)
            suite_hit.update(bins)
    return {
        "compile": compile_record,
        "tests": records,
        "passed": sum(record["status"] == "pass" for record in records),
        "failed": sum(record["status"] != "pass" for record in records),
        "hit": sorted(suite_hit),
        "missed": sorted(ALL_COVERAGE_BINS - suite_hit),
    }


def run_assertion_suite(
    core_directory: Path,
    tests: Iterable[TestProgram],
    assertion_file: Path,
) -> Dict[str, Any]:
    """Run assertions on the correct core and collect false-positive names."""
    tests = list(tests)
    with tempfile.TemporaryDirectory(prefix="a3-assertions-") as temporary:
        work_directory = Path(temporary)
        executable, compile_record = compile_core(
            core_directory,
            work_directory,
            ASSERTION_TB,
            "core_tb_assert",
            [Path(assertion_file)],
        )
        if executable is None:
            return {
                "compile": compile_record,
                "tests": [],
                "passed": 0,
                "failed": len(tests),
                "assertion_failures": [],
                "silent": False,
            }
        records = []
        fired = set()
        for test in tests:
            record = run_test(executable, test, work_directory)
            failures = sorted(set(re.findall(
                r"^ASSERT_FAIL\s+([A-Za-z_][A-Za-z0-9_]*)",
                record.get("output", ""),
                flags=re.MULTILINE,
            )))
            fired.update(failures)
            record["assertion_failures"] = failures
            record.pop("output", None)
            records.append(record)
    passed = sum(record["status"] == "pass" for record in records)
    return {
        "compile": compile_record,
        "tests": records,
        "passed": passed,
        "failed": len(records) - passed,
        "assertion_failures": sorted(fired),
        "silent": not fired,
    }
