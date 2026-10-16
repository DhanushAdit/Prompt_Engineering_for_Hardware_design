#!/usr/bin/env python3
"""Task 4: generate, validate, and repair invariant assertions."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


ROOT = Path(__file__).resolve().parents[1]
AGENT_DIR = Path(__file__).resolve().parent
if str(AGENT_DIR) not in sys.path:
    sys.path.insert(0, str(AGENT_DIR))

from assertion_tools import (  # noqa: E402
    REQUIRED_ASSERTIONS,
    extract_assertion_module,
    run_activation_probe,
    validate_assertion_source,
)
from llm_client import (  # noqa: E402
    DEFAULT_MAX_TOKENS,
    DEFAULT_MODEL,
    DEFAULT_TEMPERATURE,
    LLMClient,
    load_dotenv,
)
from prompts import (  # noqa: E402
    ASSERTION_PROMPT_VERSION,
    ASSERTION_SYSTEM_PROMPT,
    assertion_generation_prompt,
    assertion_repair_prompt,
)
from rtl_runner import run_assertion_suite  # noqa: E402
from test_programs import load_manifest_tests  # noqa: E402


def read_json(path: Path) -> Dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise ValueError(f"required prior-task artifact is missing: {path}") from error
    except json.JSONDecodeError as error:
        raise ValueError(f"invalid JSON in {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object in {path}")
    return value


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def clear_old_records(*directories: Path) -> None:
    for directory in directories:
        if directory.is_dir():
            for path in directory.iterdir():
                if path.is_file():
                    path.unlink()


def compact_probe(result: Dict[str, Any]) -> Dict[str, Any]:
    compact = {
        "status": result.get("status"),
        "fired": result.get("fired", []),
        "missing": result.get("missing", []),
        "case_results": result.get("case_results", {}),
    }
    if result.get("error"):
        compact["error"] = result["error"]
    if result.get("output"):
        compact["output"] = str(result["output"])[-6000:]
    return compact


def compact_suite(result: Dict[str, Any]) -> Dict[str, Any]:
    compile_record = result.get("compile", {})
    compact: Dict[str, Any] = {
        "compile_status": compile_record.get("status"),
        "passed": result.get("passed", 0),
        "failed": result.get("failed", 0),
        "silent": result.get("silent", False),
        "assertion_failures": result.get("assertion_failures", []),
        "tests": [
            {
                "name": record.get("name"),
                "status": record.get("status"),
                "verdict": record.get("verdict"),
                "assertion_failures": record.get("assertion_failures", []),
            }
            for record in result.get("tests", [])
        ],
    }
    if compile_record.get("error"):
        compact["compile_error"] = compile_record["error"]
    if compile_record.get("output") and compile_record.get("status") != "pass":
        compact["compile_output"] = str(compile_record["output"])[-6000:]
    return compact


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate and validate Task 4 assertions.")
    parser.add_argument("--provider", required=True, choices=["tamu", "openai"])
    parser.add_argument("--out", required=True, help="existing cumulative results directory")
    parser.add_argument("--core", required=True, help="core directory containing datapath_pipelined.sv")
    parser.add_argument("--max-calls", required=True, type=int, help="total Task 2+3+4 call budget")
    parser.add_argument("--model", default=None)
    parser.add_argument("--max-tokens", type=int, default=None)
    parser.add_argument("--temperature", type=float, default=None)
    parser.add_argument("--max-rounds", type=int, default=5)
    return parser


def main(argv: List[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.max_calls < 1:
        raise SystemExit("--max-calls must be at least 1")
    if args.max_rounds < 1:
        raise SystemExit("--max-rounds must be at least 1")

    load_dotenv(ROOT)
    output_dir = Path(args.out).expanduser().resolve()
    core_dir = Path(args.core).expanduser().resolve()
    tests_dir = output_dir / "tests"
    records_dir = output_dir / "run_records"
    manifest_path = records_dir / "test_manifest.json"
    coverage_summary_path = records_dir / "coverage_summary.json"
    assertion_records = records_dir / "assertions"
    assertion_calls = records_dir / "assertion_calls"
    assertion_records.mkdir(parents=True, exist_ok=True)
    assertion_calls.mkdir(parents=True, exist_ok=True)

    try:
        prior_summary = read_json(coverage_summary_path)
        tests = load_manifest_tests(tests_dir, manifest_path)
        template = (ROOT / "harness" / "assertions_template.sv").read_text(encoding="utf-8")
        specification = (ROOT / "docs" / "required_invariants.md").read_text(encoding="utf-8")
    except (ValueError, OSError) as error:
        print(f"configuration error: {error}", file=sys.stderr)
        return 2

    clear_old_records(assertion_records, assertion_calls)
    prior_calls = int(prior_summary.get("total_calls_used", 0))
    remaining_budget = max(0, args.max_calls - prior_calls)
    model = args.model or str(prior_summary.get("requested_model") or DEFAULT_MODEL)
    settings = prior_summary.get("settings", {})
    max_tokens = args.max_tokens if args.max_tokens is not None else int(
        settings.get("max_tokens", DEFAULT_MAX_TOKENS)
    )
    temperature = args.temperature if args.temperature is not None else float(
        settings.get("temperature", DEFAULT_TEMPERATURE)
    )
    if not remaining_budget:
        print(f"LLM call budget exhausted ({prior_calls}/{args.max_calls})", file=sys.stderr)
        return 1

    try:
        client = LLMClient(
            provider=args.provider,
            model=model,
            max_calls=remaining_budget,
            log_dir=assertion_calls,
            max_tokens=max_tokens,
            temperature=temperature,
        )
    except (RuntimeError, ValueError) as error:
        print(f"configuration error: {error}", file=sys.stderr)
        return 2

    started = datetime.now(timezone.utc).isoformat()
    accepted_source = ""
    previous_source = ""
    previous_errors: List[str] = []
    final_probe: Dict[str, Any] = {}
    final_suite: Dict[str, Any] = {}
    stop_reason = "max_rounds_reached"

    for round_number in range(1, args.max_rounds + 1):
        if client.calls_remaining <= 0:
            stop_reason = "call_budget_exhausted"
            break
        prompt = (
            assertion_generation_prompt(template, specification)
            if round_number == 1
            else assertion_repair_prompt(template, specification, previous_source, previous_errors)
        )
        errors: List[str] = []
        source = ""
        try:
            response = client.generate(
                ASSERTION_SYSTEM_PROMPT,
                prompt,
                purpose=(
                    "task4_assertion_generation" if round_number == 1
                    else f"task4_assertion_repair_{round_number - 1}"
                ),
            )
            source = extract_assertion_module(response["content"])
        except (RuntimeError, ValueError) as error:
            errors.append(str(error))

        candidate_path = assertion_records / f"candidate_{round_number:03d}.sv"
        if source:
            candidate_path.write_text(source, encoding="utf-8")
            errors.extend(validate_assertion_source(source))

        probe: Dict[str, Any] = {"status": "not_run", "fired": [], "missing": REQUIRED_ASSERTIONS}
        suite: Dict[str, Any] = {
            "compile": {"status": "not_run"}, "tests": [], "passed": 0,
            "failed": len(tests), "silent": False, "assertion_failures": [],
        }
        if source and not errors:
            probe = run_activation_probe(candidate_path)
            if probe.get("status") != "pass":
                errors.append(
                    f"activation probe status={probe.get('status')}; "
                    f"missing={probe.get('missing', [])}; "
                    f"details={str(probe.get('error') or probe.get('output', ''))[-3000:]}"
                )
            if probe.get("status") in {"pass", "missing_assertion_firings"}:
                suite = run_assertion_suite(core_dir, tests, candidate_path)
                compile_status = suite.get("compile", {}).get("status")
                if compile_status != "pass":
                    compile_details = suite.get("compile", {}).get("error") or suite.get("compile", {}).get("output", "")
                    errors.append(f"correct-core assertion compile status={compile_status}: {str(compile_details)[-3000:]}")
                if suite.get("failed"):
                    failed_names = [
                        record.get("name") for record in suite.get("tests", [])
                        if record.get("status") != "pass"
                    ]
                    errors.append(f"correct-core signature failures: {failed_names}")
                if suite.get("assertion_failures"):
                    errors.append(
                        f"false-positive assertions on correct core: {suite['assertion_failures']}"
                    )

        accepted = bool(source) and not errors
        write_json(assertion_records / f"iteration_{round_number:03d}.json", {
            "round": round_number,
            "prompt_version": ASSERTION_PROMPT_VERSION,
            "candidate_file": str(candidate_path),
            "structural_requirements": REQUIRED_ASSERTIONS,
            "activation_probe": compact_probe(probe),
            "correct_core_validation": compact_suite(suite),
            "validation_errors": errors,
            "accepted": accepted,
        })
        previous_source = source
        previous_errors = errors
        final_probe = probe
        final_suite = suite
        if accepted:
            accepted_source = source
            stop_reason = "assertions_valid"
            break

    assertions_path = output_dir / "assertions.sv"
    if accepted_source:
        assertions_path.write_text(accepted_source, encoding="utf-8")

    task4_calls = client.calls_used
    summary = {
        "task": 4,
        "prompt_version": ASSERTION_PROMPT_VERSION,
        "started_utc": started,
        "finished_utc": datetime.now(timezone.utc).isoformat(),
        "provider": args.provider,
        "requested_model": model,
        "settings": {"max_tokens": max_tokens, "temperature": temperature},
        "global_call_budget": args.max_calls,
        "prior_calls_used": prior_calls,
        "task4_calls_used": task4_calls,
        "total_calls_used": prior_calls + task4_calls,
        "token_usage": client.total_usage,
        "test_count": len(tests),
        "required_assertions": REQUIRED_ASSERTIONS,
        "activation_probe": compact_probe(final_probe),
        "correct_core_validation": compact_suite(final_suite),
        "assertions_file": str(assertions_path),
        "completion": bool(accepted_source),
        "stop_reason": stop_reason,
    }
    write_json(records_dir / "assertion_summary.json", summary)

    if accepted_source:
        print(f"Generated {len(REQUIRED_ASSERTIONS)} required assertions")
        print(f"Activation probe: {len(final_probe.get('fired', []))}/{len(REQUIRED_ASSERTIONS)} assertions fired")
        print(f"Correct core: {final_suite.get('passed', 0)}/{len(tests)} tests passed; no ASSERT_FAIL")
        print(f"LLM calls: Task 4 used {task4_calls}; total {prior_calls + task4_calls}/{args.max_calls}")
        print(f"Artifacts: {output_dir}")
        return 0

    print(f"No valid assertion module was produced; stop reason: {stop_reason}", file=sys.stderr)
    print(f"Inspect {assertion_records} and {assertion_calls}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
