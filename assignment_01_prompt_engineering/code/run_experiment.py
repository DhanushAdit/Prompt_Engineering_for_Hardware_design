"""Run the frozen 4-block x 3-style x 2-repeat submission experiment."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
import hashlib
import itertools
import json
from pathlib import Path
import sys

PACKAGE = Path(__file__).resolve().parent / "A1_student"
sys.path.insert(0, str(PACKAGE / "student_code"))
from workflow_tools import run_bounded, write_record

BLOCKS = ["alu", "regfile", "extend", "controller"]
STYLES = ["direct", "rules_constraints", "template_fill"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=PACKAGE.parents[1] / "run_records" / "experiment_001")
    parser.add_argument("--provider", choices=["tamu", "openai"], default="tamu")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=False)
    manifest = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "model": "gpt-5.4", "provider": args.provider, "max_output_tokens": 8192,
        "max_repairs_per_artifact": 3, "blocks": BLOCKS, "styles": STYLES,
        "repetitions": 2, "workers": args.workers,
        "frozen_files_sha256": {
            str(p.relative_to(PACKAGE)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(PACKAGE.rglob("*")) if p.is_file() and p.suffix in {".py", ".yaml", ".sv", ".sh", ".txt"}
            and "__pycache__" not in p.parts
        },
        "runs": [],
    }
    jobs = list(itertools.product(BLOCKS, STYLES, [1, 2]))
    write_record(root / "manifest.json", manifest)

    def run(job):
        block, style, repetition = job
        out = root / block / style / f"run_{repetition:02d}"
        out.mkdir(parents=True)
        command = [sys.executable, str(PACKAGE / "student_code/lab1.py"),
                   "--spec", str(PACKAGE / "specs" / f"{block}.yaml"),
                   "--out-dir", str(out), "--provider", args.provider]
        result = run_bounded(command, timeout=900,
                             env={"A1_PROMPT_STYLE": style, "A1_MAX_OUTPUT_TOKENS": "8192"})
        write_record(out / "process.json", result)
        (out / "process.log").write_text(result["log"])
        histories = list(out.glob("*_run_*/phase_c.json"))
        status = json.loads(histories[0].read_text())["status"] if histories else "NO_RESULT"
        return {"block": block, "style": style, "repetition": repetition,
                "directory": str(out.relative_to(root)), "status": status,
                "exit_code": result["exit_code"], "timed_out": result["timed_out"]}

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        pending = [pool.submit(run, job) for job in jobs]
        for future in as_completed(pending):
            result = future.result()
            manifest["runs"].append(result)
            write_record(root / "manifest.json", manifest)
            print(f"[{len(manifest['runs'])}/24] {result['block']} {result['style']} "
                  f"run {result['repetition']}: {result['status']}", flush=True)
    manifest["finished_utc"] = datetime.now(timezone.utc).isoformat()
    write_record(root / "manifest.json", manifest)
    print(f"Experiment complete. Manifest: {root / 'manifest.json'}")


if __name__ == "__main__":
    main()
