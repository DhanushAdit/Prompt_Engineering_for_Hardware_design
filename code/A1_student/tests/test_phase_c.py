"""Offline checks for result interpretation and bounded repair routing."""

import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "student_code"))
import lab1
from workflow_tools import result_passed, run_bounded


class PhaseCTests(unittest.TestCase):
    def test_result_contract(self):
        good = {"exit_code": 0, "timed_out": False,
                "log": "SUMMARY checks=3 failures=0\nPASS\n"}
        self.assertTrue(result_passed(good))
        for change in ({"exit_code": 1}, {"timed_out": True},
                       {"log": "PASS\n"},
                       {"log": "SUMMARY checks=0 failures=0\nPASS\n"},
                       {"log": "SUMMARY checks=3 failures=1\nPASS\n"},
                       {"log": good["log"] + "MISMATCH\n"},
                       {"log": good["log"] * 2}):
            with self.subTest(change=change):
                self.assertFalse(result_passed(dict(good, **change)))
        sample = dict(good, log="Passed: 40\nFailed: 0\nTotal : 40\nPASS\n>>> RESULT: PASS\n")
        self.assertTrue(result_passed(sample, sample=True))
        self.assertFalse(result_passed(dict(sample, log=sample["log"].replace("Passed: 40", "Passed: 39")), sample=True))

    def test_timeout_and_missing_tool(self):
        result = run_bounded([sys.executable, "-c", "import time; time.sleep(10)"], timeout=0.1)
        self.assertTrue(result["timed_out"])
        self.assertNotEqual(result["exit_code"], 0)
        self.assertTrue(run_bounded(["/nonexistent/a1-command"])["tool_error"])

    def exercise(self, rtl_passes, tb_passes):
        calls = []

        def generate(prompt, system_prompt=None):
            calls.append(prompt)
            return SimpleNamespace(content="module placeholder; endmodule\n",
                                   model="gpt-5.4", provider="offline-test", settings={}, usage={}, raw={})

        def run(command, **kwargs):
            if command[0] == "bash":
                log = ("Passed: 1\nFailed: 0\nTotal : 1\nPASS\n>>> RESULT: PASS\n"
                       if rtl_passes else "Passed: 0\nFailed: 1\nTotal : 1\nFAIL\n>>> RESULT: FAIL\n")
                code = 0 if rtl_passes else 1
            elif command[0] == "vvp":
                log = "SUMMARY checks=1 failures=0\nPASS\n" if tb_passes else "SUMMARY checks=1 failures=1\nFAIL\n"
                code = 0 if tb_passes else 1
            else:
                log, code = "", 0
            return {"command": [str(x) for x in command], "log": log,
                    "exit_code": code, "timed_out": False, "tool_error": False}

        with tempfile.TemporaryDirectory() as temporary:
            out = Path(temporary)
            argv = ["lab1.py", "--spec", str(ROOT / "specs/alu.yaml"), "--out-dir", str(out)]
            with patch.object(sys, "argv", argv), patch.object(lab1, "build_llm_client", return_value=SimpleNamespace(generate_full=generate)), patch.object(lab1, "run_iverilog_compile", return_value=(True, "")), patch("workflow_tools.run_bounded", side_effect=run):
                if rtl_passes and tb_passes:
                    lab1.main()
                else:
                    with self.assertRaises(SystemExit):
                        lab1.main()
            folder = next(out.glob("*_run_*"))
            history = json.loads((folder / "phase_c.json").read_text())
            self.assertEqual((folder / "alu_rules_constraints_initial_rtl.sv").read_text(), "module placeholder; endmodule\n")
            self.assertEqual((out / "final_rtl.sv").exists(), rtl_passes and tb_passes)
            self.assertEqual((out / "alu_tb.sv").exists(), rtl_passes and tb_passes)
            return history, calls

    def test_stop_on_success(self):
        history, calls = self.exercise(True, True)
        self.assertEqual(history["status"], "PASS")
        self.assertEqual(len(calls), 2)

    def test_rtl_retry_limit_and_tb_skip(self):
        history, calls = self.exercise(False, False)
        self.assertEqual(history["status"], "RTL_UNRESOLVED")
        self.assertEqual(len(history["rtl"]), 4)
        self.assertEqual(history["tb"], [])
        self.assertEqual(len(calls), 5)
        self.assertTrue(all("Repair only the RTL" in prompt for prompt in calls[2:]))

    def test_tb_failure_never_repairs_rtl(self):
        history, calls = self.exercise(True, False)
        self.assertEqual(history["status"], "TB_UNRESOLVED")
        self.assertEqual(len(history["rtl"]), 1)
        self.assertEqual(len(history["tb"]), 4)
        self.assertEqual(len(calls), 5)
        self.assertTrue(all("Repair only the testbench" in prompt for prompt in calls[2:]))


if __name__ == "__main__":
    unittest.main()
