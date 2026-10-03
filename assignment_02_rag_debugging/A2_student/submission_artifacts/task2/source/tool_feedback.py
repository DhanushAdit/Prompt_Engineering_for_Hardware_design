"""Helpers for turning Icarus/sample-test output into compact LLM feedback."""
from dataclasses import dataclass
import re
import subprocess

@dataclass
class ToolResult:
    returncode:int
    stdout:str
    stderr:str
    status:str

def classify_status(returncode:int, stdout:str, stderr:str) -> str:
    """Classify a tool run into one structured status (YOU implement this - Phase C).

    This is the agent's core "read the tool output" skill: decide whether the flow passed,
    failed to compile, or compiled-and-ran-but-failed a functional check. Return exactly one of:
      - 'pass'          : the flow succeeded (return code 0).
      - 'compile_error' : a compile/elaboration/tool error (before any functional check ran) -
                          look for iverilog error text such as 'syntax error' or 'error:'.
      - 'sim_fail'      : it compiled and ran, but a functional check failed (non-zero exit,
                          no compile error).
    Distinguishing 'the tool ran' from 'the design is correct' is the point - the repair loop and
    keep-best both depend on this being right.
    """
    # >>> BEGIN STUDENT PHASE C (status classification)
    # The runner scripts return zero only after compilation and the functional
    # checker both succeed.  Warnings on stderr therefore must not turn a pass
    # into a failure.
    if returncode == 0:
        return "pass"

    output = f"{stdout}\n{stderr}".lower()
    compile_patterns = (
        r"\berror\s*:",
        r"syntax\s+error",
        r"parse\s+error",
        r"unknown\s+module\s+type",
        r"unable\s+to\s+bind",
        r"not\s+a\s+port\b",
        r"has\s+no\s+port",
        r"elaborat(?:e|ion)",
        r"cannot\s+(?:open|find|locate)",
        r"no\s+such\s+file",
        r"command\s+not\s+found",
        r"failed\s+to\s+open",
    )
    if any(re.search(pattern, output) for pattern in compile_patterns):
        return "compile_error"

    # A non-zero run without compiler/elaboration diagnostics reached the
    # simulation/checker stage (for example, a vector mismatch or timeout).
    return "sim_fail"
    # <<< END STUDENT PHASE C (status classification)

def run_command(command:list[str]) -> ToolResult:
    """Run a tool command and classify its result via classify_status (Phase C)."""
    p=subprocess.run(command,text=True,capture_output=True)
    status=classify_status(p.returncode,p.stdout,p.stderr)
    return ToolResult(p.returncode,p.stdout,p.stderr,status)

def compact_feedback(r:ToolResult,max_chars:int=5000)->str:
    body=(r.stdout+'\n'+r.stderr).strip()
    if len(body)>max_chars: body=body[-max_chars:]
    return f"Tool status: {r.status}\nReturn code: {r.returncode}\nRelevant output:\n{body}"
