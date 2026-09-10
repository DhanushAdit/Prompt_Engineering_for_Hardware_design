"""Bounded process execution and result records for the student workflow."""

import json
import os
from pathlib import Path
import re
import signal
import subprocess
from tempfile import TemporaryDirectory


def experiment_settings():
    style = os.environ.get("A1_PROMPT_STYLE", "rules_constraints")
    if style not in {"direct", "rules_constraints", "template_fill"}:
        raise ValueError(f"Unsupported A1_PROMPT_STYLE: {style}")
    limit = int(os.environ.get("A1_MAX_OUTPUT_TOKENS", "4096"))
    if limit <= 0:
        raise ValueError("A1_MAX_OUTPUT_TOKENS must be positive")
    return style, limit


def write_record(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def run_bounded(command, timeout=30, env=None):
    command = [str(part) for part in command]
    record = {"command": command, "timed_out": False}
    try:
        process = subprocess.Popen(
            command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, start_new_session=True,
            env=dict(os.environ, **(env or {})),
        )
    except OSError as error:
        return dict(record, exit_code=None, log=str(error), tool_error=True)
    try:
        log, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        # Kill the script and its compiler/simulator children, not just the shell.
        os.killpg(process.pid, signal.SIGKILL)
        log, _ = process.communicate()
        record["timed_out"] = True
    return dict(record, exit_code=process.returncode, log=log, tool_error=False)


def result_passed(record, sample=False):
    if record["exit_code"] != 0 or record["timed_out"] or record.get("tool_error"):
        return False
    log = record["log"]
    lines = [line.strip() for line in log.splitlines()]
    if re.search(r"\b(?:FAIL|FATAL|MISMATCH)\b", log, re.IGNORECASE):
        return False
    if "PASS" not in lines:
        return False
    if sample:
        passed = re.findall(r"^Passed:\s*(\d+)\s*$", log, re.MULTILINE)
        failed = re.findall(r"^Failed:\s*(\d+)\s*$", log, re.MULTILINE)
        total = re.findall(r"^Total\s*:\s*(\d+)\s*$", log, re.MULTILINE)
        return (">>> RESULT: PASS" in lines and len(passed) == len(failed) == len(total) == 1
                and int(total[0]) > 0 and int(passed[0]) == int(total[0])
                and int(failed[0]) == 0)
    summaries = re.findall(r"^SUMMARY checks=(\d+) failures=(\d+)\s*$", log, re.MULTILINE)
    return len(summaries) == 1 and int(summaries[0][0]) > 0 and int(summaries[0][1]) == 0
