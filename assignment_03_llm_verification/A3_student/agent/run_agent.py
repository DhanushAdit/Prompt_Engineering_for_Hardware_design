#!/usr/bin/env python3
"""Assignment 3 Verification Agent: generated tests, mutation checking, and coverage feedback."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
AGENT_DIR = Path(__file__).resolve().parent
if str(AGENT_DIR) not in sys.path:
    sys.path.insert(0, str(AGENT_DIR))

from llm_client import (  # noqa: E402
    CallBudgetExceeded,
    DEFAULT_MAX_TOKENS,
    DEFAULT_MODEL,
    DEFAULT_TEMPERATURE,
    LLMClient,
    load_dotenv,
)
from mutations import run_mutations  # noqa: E402
from prompts import PROMPT_VERSION, SYSTEM_PROMPT, initial_test_prompt, repair_prompt  # noqa: E402
from rtl_runner import run_suite  # noqa: E402
from test_programs import TestProgram, parse_generated_tests, seed_tests, write_tests  # noqa: E402


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def remove_previous_agent_tests(tests_dir: Path, manifest_path: Path) -> None:
    """Remove only files named by this agent's previous manifest; preserve unrelated user tests."""
    if not manifest_path.is_file():
        return
    try:
        previous = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return
    for entry in previous.get("tests", []):
        name = entry.get("name") if isinstance(entry, dict) else None
        if isinstance(name, str):
            path = tests_dir / f"{name}.hex"
            if path.is_file():
                path.unlink()


def merge_tests(current: List[TestProgram], additions: Iterable[TestProgram]) -> Tuple[List[TestProgram], List[str]]:
    names = {test.name for test in current}
    accepted = list(current)
    errors: List[str] = []
    for test in additions:
        if test.name in names:
            errors.append(f"duplicate test name across calls: {test.name}")
            continue
        names.add(test.name)
        accepted.append(test)
    return accepted, errors


def llm_generate(
    client: LLMClient,
    prompt: str,
    purpose: str,
) -> Tuple[List[TestProgram], List[str]]:
    try:
        result = client.generate(SYSTEM_PROMPT, prompt, purpose=purpose)
        tests, errors = parse_generated_tests(
            result["content"], origin=f"llm_call_{client.calls_used:03d}"
        )
        if not tests:
            errors.append("response contained no valid tests")
        return tests, errors
    except (RuntimeError, ValueError, json.JSONDecodeError) as error:
        return [], [str(error)]


def summarize_suite(result: Dict[str, object]) -> Dict[str, object]:
    return {
        "compile_status": result["compile"]["status"],
        "passed": result["passed"],
        "failed": result["failed"],
        "tests": [
            {
                "name": entry["name"],
                "target_family": entry.get("target_family"),
                "status": entry["status"],
                "expected_signature": entry.get("expected_signature"),
                "verdict": entry.get("verdict"),
            }
            for entry in result.get("tests", [])
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate RV32I tests, validate bug detection, close coverage, and create assertions."
    )
    parser.add_argument("--provider", required=True, choices=["tamu", "openai"])
    parser.add_argument("--out", required=True, help="output directory, e.g. results")
    parser.add_argument("--core", required=True, help="core directory containing datapath_pipelined.sv")
    parser.add_argument("--max-calls", required=True, type=int, help="hard limit including retries")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--max-tokens", type=int, default=DEFAULT_MAX_TOKENS)
    parser.add_argument("--temperature", type=float, default=DEFAULT_TEMPERATURE)
    parser.add_argument(
        "--stop-after", choices=["task2", "task3", "task4"], default="task4",
        help="development aid; the required command continues through Task 4 by default",
    )
    return parser


def main(argv: List[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.max_calls < 1:
        raise SystemExit("--max-calls must be at least 1")
    if args.max_tokens < 1:
        raise SystemExit("--max-tokens must be at least 1")

    # Match the Assignment 2 pattern: always load A3_student/.env based on this file,
    # independent of the caller's current working directory. Exported variables win.
    load_dotenv(ROOT)

    output_dir = Path(args.out).expanduser().resolve()
    core_dir = Path(args.core).expanduser().resolve()
    tests_dir = output_dir / "tests"
    records_dir = output_dir / "run_records"
    calls_dir = records_dir / "calls"
    manifest_path = records_dir / "test_manifest.json"
    output_dir.mkdir(parents=True, exist_ok=True)
    tests_dir.mkdir(parents=True, exist_ok=True)
    records_dir.mkdir(parents=True, exist_ok=True)
    remove_previous_agent_tests(tests_dir, manifest_path)
    if calls_dir.is_dir():
        for old_call_log in calls_dir.glob("call_*.json"):
            old_call_log.unlink()

    started = datetime.now(timezone.utc).isoformat()
    try:
        client = LLMClient(
            provider=args.provider,
            model=args.model,
            max_calls=args.max_calls,
            log_dir=calls_dir,
            max_tokens=args.max_tokens,
            temperature=args.temperature,
        )
    except (RuntimeError, ValueError) as error:
        print(f"configuration error: {error}", file=sys.stderr)
        return 2

    tests = seed_tests()
    validation_errors: List[str] = []
    llm_tests: List[TestProgram] = []

    generated, errors = llm_generate(client, initial_test_prompt(), "task2_initial_test_generation")
    validation_errors.extend(errors)
    llm_tests, merge_errors = merge_tests(llm_tests, generated)
    validation_errors.extend(merge_errors)
    last_errors = errors + merge_errors

    # Repair malformed output or fill model-generation family gaps before simulation.
    for attempt in range(5):
        llm_families = {test.target_family for test in llm_tests}
        missing = sorted({
            "forwarding", "x0_integrity", "load_use", "flush_redirect", "branch_jump_target"
        } - llm_families)
        if not missing and not last_errors:
            break
        if client.calls_remaining <= 0:
            break
        generated, errors = llm_generate(
            client,
            repair_prompt(validation_errors, missing),
            f"task2_generation_repair_{attempt + 1}",
        )
        validation_errors.extend(errors)
        llm_tests, merge_errors = merge_tests(llm_tests, generated)
        validation_errors.extend(merge_errors)
        last_errors = errors + merge_errors

    tests, merge_errors = merge_tests(tests, llm_tests)
    validation_errors.extend(merge_errors)
    write_tests(tests, tests_dir)

    suite_result = run_suite(core_dir, tests)
    write_json(records_dir / "selected_core_results.json", suite_result)

    mutation_result: Dict[str, object] = {
        "mutations": [],
        "families_detected": [],
        "families_missed": [],
    }
    if suite_result["compile"]["status"] == "pass" and suite_result["failed"] == 0:
        mutation_result = run_mutations(core_dir, tests, records_dir / "mutants")

        # Ask for targeted additions if a representative mutant survived, then revalidate.
        feedback_round = 0
        while mutation_result["families_missed"] and client.calls_remaining > 0 and feedback_round < 3:
            feedback_round += 1
            generated, errors = llm_generate(
                client,
                repair_prompt(validation_errors, mutation_result["families_missed"]),
                f"task2_mutation_feedback_{feedback_round}",
            )
            validation_errors.extend(errors)
            tests, merge_errors = merge_tests(tests, generated)
            validation_errors.extend(merge_errors)
            write_tests(tests, tests_dir)
            suite_result = run_suite(core_dir, tests)
            write_json(records_dir / "selected_core_results.json", suite_result)
            if suite_result["compile"]["status"] != "pass" or suite_result["failed"]:
                break
            mutation_result = run_mutations(core_dir, tests, records_dir / "mutants")

    write_json(records_dir / "mutation_results.json", mutation_result)
    manifest = {
        "prompt_version": PROMPT_VERSION,
        "tests": [test.manifest_entry() for test in tests],
        "validation_errors": validation_errors,
    }
    write_json(manifest_path, manifest)

    summary = {
        "task": 2,
        "started_utc": started,
        "finished_utc": datetime.now(timezone.utc).isoformat(),
        "provider": args.provider,
        "requested_model": args.model,
        "settings": {"max_tokens": args.max_tokens, "temperature": args.temperature},
        "max_calls": args.max_calls,
        "calls_used": client.calls_used,
        "calls_remaining": client.calls_remaining,
        "token_usage": client.total_usage,
        "core_directory": str(core_dir),
        "output_directory": str(output_dir),
        "test_count": len(tests),
        "llm_test_count": sum(test.origin.startswith("llm_call_") for test in tests),
        "seed_test_count": sum(test.origin == "deterministic_seed" for test in tests),
        "selected_core": summarize_suite(suite_result),
        "mutation_families_detected": mutation_result["families_detected"],
        "mutation_families_missed": mutation_result["families_missed"],
        "completion": {
            "llm_generated_valid_test": bool(llm_tests),
            "selected_core_compiled": suite_result["compile"]["status"] == "pass",
            "all_tests_pass_selected_core": suite_result["failed"] == 0,
            "all_mutation_families_detected": not mutation_result["families_missed"] and bool(mutation_result["mutations"]),
        },
    }
    write_json(records_dir / "run_summary.json", summary)

    print(f"Generated {len(tests)} tests ({summary['llm_test_count']} from LLM, {summary['seed_test_count']} seeds).")
    print(f"LLM calls: {client.calls_used}/{client.max_calls}")
    print(f"Selected core: {suite_result['passed']}/{len(tests)} tests passed")
    if mutation_result["mutations"]:
        print("Mutation families detected:", ", ".join(mutation_result["families_detected"]) or "none")
        if mutation_result["families_missed"]:
            print("Mutation families missed:", ", ".join(mutation_result["families_missed"]))
    print(f"Artifacts: {output_dir}")

    if suite_result["compile"]["status"] != "pass":
        print("The selected core did not compile; see run_records/selected_core_results.json.", file=sys.stderr)
        return 2
    if not llm_tests:
        print("No valid LLM-generated test was produced; inspect run_records/calls.", file=sys.stderr)
        return 1
    if suite_result["failed"]:
        print("The generated suite detected one or more selected-core mismatches.")
    if mutation_result["families_missed"]:
        return 1
    if args.stop_after == "task2":
        return 0

    # The required run_agent.py interface is the end-to-end entry point. The
    # coverage stage reloads the suite and subtracts Task 2 calls from the same
    # global call budget.
    from coverage_loop import main as coverage_main

    shared_stage_args = [
        "--provider", args.provider,
        "--out", str(output_dir),
        "--core", str(core_dir),
        "--max-calls", str(args.max_calls),
        "--model", args.model,
        "--max-tokens", str(args.max_tokens),
        "--temperature", str(args.temperature),
    ]
    coverage_status = coverage_main(shared_stage_args)
    if coverage_status != 0 or args.stop_after == "task3":
        return coverage_status

    from assertion_loop import main as assertion_main

    return assertion_main(shared_stage_args)


if __name__ == "__main__":
    raise SystemExit(main())
