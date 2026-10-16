#!/usr/bin/env python3
"""Task 3: close measured coverage gaps using bounded LLM feedback."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
AGENT_DIR = Path(__file__).resolve().parent
if str(AGENT_DIR) not in sys.path:
    sys.path.insert(0, str(AGENT_DIR))

from llm_client import (  # noqa: E402
    DEFAULT_MAX_TOKENS,
    DEFAULT_MODEL,
    DEFAULT_TEMPERATURE,
    LLMClient,
    load_dotenv,
)
from prompts import (  # noqa: E402
    COVERAGE_PROMPT_VERSION,
    SYSTEM_PROMPT,
    coverage_feedback_prompt,
)
from rtl_runner import ALL_COVERAGE_BINS, run_coverage_suite  # noqa: E402
from test_programs import (  # noqa: E402
    TestProgram,
    load_manifest_tests,
    parse_generated_tests,
    write_tests,
)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def read_json(path: Path) -> Dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise ValueError(f"required Task 2 artifact is missing: {path}") from error
    except json.JSONDecodeError as error:
        raise ValueError(f"invalid JSON in {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object in {path}")
    return value


def reset_previous_coverage_additions(tests_dir: Path, manifest_path: Path) -> Dict[str, Any]:
    """Make repeated Task 3 runs start from the saved Task 2 suite."""
    manifest = read_json(manifest_path)
    entries = manifest.get("tests")
    if not isinstance(entries, list):
        raise ValueError("test manifest has no tests array")
    baseline_entries = []
    for entry in entries:
        origin = str(entry.get("origin", "")) if isinstance(entry, dict) else ""
        if origin.startswith("coverage_llm_call_"):
            name = entry.get("name")
            if isinstance(name, str):
                path = tests_dir / f"{name}.hex"
                if path.is_file():
                    path.unlink()
        else:
            baseline_entries.append(entry)
    manifest["tests"] = baseline_entries
    manifest.pop("coverage_additions", None)
    manifest.pop("coverage_prompt_version", None)
    write_json(manifest_path, manifest)
    return manifest


def clear_old_records(*directories: Path) -> None:
    for directory in directories:
        if directory.is_dir():
            for path in directory.glob("*.json"):
                path.unlink()


def coverage_measurement(result: Dict[str, Any]) -> Dict[str, Any]:
    hit = sorted(set(result.get("hit", [])) & ALL_COVERAGE_BINS)
    missed = sorted(ALL_COVERAGE_BINS - set(hit))
    return {
        "bins_hit": len(hit),
        "bins_total": len(ALL_COVERAGE_BINS),
        "percent": round(100.0 * len(hit) / len(ALL_COVERAGE_BINS), 2),
        "hit": hit,
        "missed": missed,
        "passing_tests": result.get("passed", 0),
        "failing_tests": result.get("failed", 0),
    }


def compact_result(result: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "compile_status": result.get("compile", {}).get("status"),
        "passed": result.get("passed", 0),
        "failed": result.get("failed", 0),
        "hit": result.get("hit", []),
        "missed": result.get("missed", []),
        "tests": [
            {
                "name": record.get("name"),
                "status": record.get("status"),
                "verdict": record.get("verdict"),
                "coverage_bins": record.get("coverage_bins", []),
            }
            for record in result.get("tests", [])
        ],
    }


def merge_new_tests(
    current: List[TestProgram], additions: Iterable[TestProgram]
) -> Tuple[List[TestProgram], List[TestProgram], List[str]]:
    names = {test.name for test in current}
    merged = list(current)
    accepted = []
    errors = []
    for test in additions:
        if test.name in names:
            errors.append(f"duplicate test name: {test.name}")
            continue
        names.add(test.name)
        merged.append(test)
        accepted.append(test)
    return merged, accepted, errors


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Use RTL coverage feedback to extend the Task 2 suite.")
    parser.add_argument("--provider", required=True, choices=["tamu", "openai"])
    parser.add_argument("--out", required=True, help="existing Task 2 output directory")
    parser.add_argument("--core", required=True, help="core directory containing datapath_pipelined.sv")
    parser.add_argument("--max-calls", required=True, type=int, help="total Task 2+3 call budget")
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
    task2_summary_path = records_dir / "run_summary.json"
    coverage_records = records_dir / "coverage"
    coverage_calls = records_dir / "coverage_calls"
    coverage_records.mkdir(parents=True, exist_ok=True)
    coverage_calls.mkdir(parents=True, exist_ok=True)

    try:
        manifest = reset_previous_coverage_additions(tests_dir, manifest_path)
        task2_summary = read_json(task2_summary_path)
        tests = load_manifest_tests(tests_dir, manifest_path)
    except ValueError as error:
        print(f"configuration error: {error}", file=sys.stderr)
        return 2

    clear_old_records(coverage_records, coverage_calls)
    started = datetime.now(timezone.utc).isoformat()
    baseline = run_coverage_suite(core_dir, tests)
    write_json(coverage_records / "iteration_000_baseline.json", compact_result(baseline))
    before = coverage_measurement(baseline)
    if baseline.get("compile", {}).get("status") != "pass":
        write_json(output_dir / "coverage.json", {"before": before, "after": before})
        print("The selected core did not compile with coverage instrumentation.", file=sys.stderr)
        return 2
    if baseline.get("failed"):
        write_json(output_dir / "coverage.json", {"before": before, "after": before})
        print("The saved Task 2 suite does not pass the selected core.", file=sys.stderr)
        return 2

    task2_calls = int(task2_summary.get("calls_used", 0))
    remaining_budget = max(0, args.max_calls - task2_calls)
    model = args.model or str(task2_summary.get("requested_model") or DEFAULT_MODEL)
    settings = task2_summary.get("settings", {})
    max_tokens = args.max_tokens if args.max_tokens is not None else int(
        settings.get("max_tokens", DEFAULT_MAX_TOKENS)
    )
    temperature = args.temperature if args.temperature is not None else float(
        settings.get("temperature", DEFAULT_TEMPERATURE)
    )

    client = None
    configuration_error = None
    if before["missed"] and remaining_budget:
        try:
            client = LLMClient(
                provider=args.provider,
                model=model,
                max_calls=remaining_budget,
                log_dir=coverage_calls,
                max_tokens=max_tokens,
                temperature=temperature,
            )
        except (RuntimeError, ValueError) as error:
            configuration_error = str(error)

    current = baseline
    additions: List[TestProgram] = []
    outcomes: List[str] = []
    no_progress_rounds = 0
    stop_reason = "coverage_complete" if not before["missed"] else "not_started"

    if configuration_error:
        stop_reason = "configuration_error"
        outcomes.append(configuration_error)
    elif before["missed"] and client is None:
        stop_reason = "call_budget_exhausted"
    else:
        for round_number in range(1, args.max_rounds + 1):
            missing = current["missed"]
            if not missing:
                stop_reason = "coverage_complete"
                break
            if client is None or client.calls_remaining <= 0:
                stop_reason = "call_budget_exhausted"
                break

            prompt = coverage_feedback_prompt(
                missing,
                current["hit"],
                current.get("tests", []),
                outcomes,
            )
            validation_errors: List[str] = []
            generated: List[TestProgram] = []
            try:
                response = client.generate(
                    SYSTEM_PROMPT,
                    prompt,
                    purpose=f"task3_coverage_feedback_{round_number}",
                )
                generated, validation_errors = parse_generated_tests(
                    response["content"],
                    origin=f"coverage_llm_call_{client.calls_used:03d}",
                )
            except (RuntimeError, ValueError, json.JSONDecodeError) as error:
                validation_errors.append(str(error))

            _, unique_candidates, duplicate_errors = merge_new_tests(tests, generated)
            validation_errors.extend(duplicate_errors)
            candidate_result = run_coverage_suite(core_dir, unique_candidates) if unique_candidates else {
                "compile": {"status": "not_run"}, "tests": [], "passed": 0,
                "failed": 0, "hit": [], "missed": sorted(ALL_COVERAGE_BINS),
            }
            passing_names = {
                record["name"] for record in candidate_result.get("tests", [])
                if record.get("status") == "pass"
            }
            retained = [test for test in unique_candidates if test.name in passing_names]
            rejected = [
                {"name": record.get("name"), "status": record.get("status"),
                 "verdict": record.get("verdict")}
                for record in candidate_result.get("tests", [])
                if record.get("status") != "pass"
            ]
            tests, retained, merge_errors = merge_new_tests(tests, retained)
            validation_errors.extend(merge_errors)
            if retained:
                write_tests(retained, tests_dir)
                additions.extend(retained)

            previous_hit = set(current["hit"])
            current = run_coverage_suite(core_dir, tests)
            gained = sorted(set(current["hit"]) - previous_hit)
            if gained:
                no_progress_rounds = 0
                outcomes.append(
                    f"round {round_number}: retained {len(retained)} tests and gained {gained}"
                )
            else:
                no_progress_rounds += 1
                outcomes.append(
                    f"round {round_number}: retained {len(retained)} tests but gained no new bins; "
                    f"validation_errors={validation_errors}; rejected={rejected}"
                )

            write_json(coverage_records / f"iteration_{round_number:03d}.json", {
                "round": round_number,
                "missing_before": missing,
                "generated_tests": [test.manifest_entry() for test in generated],
                "retained_tests": [test.name for test in retained],
                "rejected_tests": rejected,
                "validation_errors": validation_errors,
                "candidate_measurement": compact_result(candidate_result),
                "bins_gained": gained,
                "cumulative_measurement": compact_result(current),
            })

            if not current["missed"]:
                stop_reason = "coverage_complete"
                break
            if no_progress_rounds >= 2:
                stop_reason = "two_consecutive_no_progress_rounds"
                break
        else:
            stop_reason = "max_rounds_reached"

    after = coverage_measurement(current)
    write_json(output_dir / "coverage.json", {"before": before, "after": after})
    manifest["tests"] = [test.manifest_entry() for test in tests]
    manifest["coverage_prompt_version"] = COVERAGE_PROMPT_VERSION
    manifest["coverage_additions"] = [test.name for test in additions]
    write_json(manifest_path, manifest)

    task3_calls = client.calls_used if client is not None else 0
    summary = {
        "task": 3,
        "started_utc": started,
        "finished_utc": datetime.now(timezone.utc).isoformat(),
        "provider": args.provider,
        "requested_model": model,
        "settings": {"max_tokens": max_tokens, "temperature": temperature},
        "global_call_budget": args.max_calls,
        "task2_calls_used": task2_calls,
        "task3_calls_used": task3_calls,
        "total_calls_used": task2_calls + task3_calls,
        "token_usage": client.total_usage if client is not None else {},
        "before": before,
        "after": after,
        "added_tests": [test.name for test in additions],
        "stop_reason": stop_reason,
        "outcomes": outcomes,
    }
    write_json(records_dir / "coverage_summary.json", summary)

    print(f"Coverage before: {before['bins_hit']}/{before['bins_total']} bins")
    print(f"Coverage after: {after['bins_hit']}/{after['bins_total']} bins")
    print(f"Added {len(additions)} passing tests")
    print(f"LLM calls: Task 3 used {task3_calls}; total {task2_calls + task3_calls}/{args.max_calls}")
    print(f"Stop reason: {stop_reason}")
    print(f"Artifacts: {output_dir}")
    if configuration_error:
        print(f"configuration error: {configuration_error}", file=sys.stderr)
        return 2
    return 0 if not after["missed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
