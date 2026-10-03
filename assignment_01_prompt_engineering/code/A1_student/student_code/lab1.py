"""Starter script for a student-designed LLM-to-RTL workflow."""

import argparse
from pathlib import Path

# Provided helpers - already imported for you. Use these in your Phase A/B/C code;
# you should not need to add imports or edit any other file.
from io_utils import (
    find_default_spec,
    load_spec,
    read_file,
    write_file,
    strip_markdown_code_blocks,
)
from llm_clients import build_llm_client
from tool_runner import run_iverilog_compile, run_vvp


DEFAULT_MODEL = "gpt-5.4"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Design an LLM-assisted RTL generation and verification workflow."
    )
    parser.add_argument("--spec", type=Path, help="Path to a YAML design specification.")
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "output",
        help="Suggested directory for generated artifacts.",
    )
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Model name (default: {DEFAULT_MODEL}). Use the same model for all runs.",
    )
    parser.add_argument(
        "--provider",
        choices=["tamu", "openai"],
        default=None,
        help="LLM access path: 'tamu' (TAMU AI Chat) or 'openai' (own key). "
             "If omitted, auto-selects by which API key is set.",
    )
    parser.add_argument(
        "--smoke-test",
        action="store_true",
        help="Make one tiny LLM request to confirm the client works, then continue. "
             "Off by default so normal runs do not spend quota on a throwaway call.",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    # Provided setup: select and load the hardware specification.
    spec_path = args.spec if args.spec else find_default_spec(Path.cwd())
    top_module, content, spec = load_spec(spec_path)

    # Provided setup: build the LLM client (TAMU AI Chat or OpenAI, same model).
    model = build_llm_client(args.model, provider=args.provider)

    print(f"Using spec: {spec_path}")
    print(f"Top module: {top_module}")
    print(f"Model: {args.model}")
    print(f"Suggested output directory: {args.out_dir.resolve()}")

    # Optional one-off check that the LLM client works (opt-in so normal runs
    # do not spend quota on a throwaway request).
    if args.smoke_test:
        test_reply = model.generate(
            "Reply with exactly: LLM client initialization successful.",
            system_prompt="Follow the user's requested output format exactly.",
        )
        print(f"LLM smoke-test reply: {test_reply}")

    # From this point onward, design and implement your own workflow. You may
    # add helper functions or modules. You may place these functions in
    # separate files and import them here.
    #
    # The three phases below are the internal steps of YOUR workflow. They are
    # NOT the five graded tasks in the handout - the handout describes the whole
    # experiment (multiple prompt styles, repeated runs, analysis) that runs on
    # top of this workflow.

    # ------------------------------------------------------------------
    # WORKFLOW PHASE A: GENERATE RTL
    # Use `content`/`spec` and `model.generate(...)` to
    # produce RTL for `top_module`, then save it so that it can be compiled.
    # Preserve the interface and behavior in the YAML spec. You need to decide
    # how to construct the prompt, clean the response, name output files, and
    # determine whether the RTL is ready for the next phase.
    #
    # >>> BEGIN STUDENT PHASE A CODE
    from workflow_tools import experiment_settings

    prompt_style, output_limit = experiment_settings()
    model = build_llm_client(args.model, provider=args.provider, max_output_tokens=output_limit)
    spec_text = read_file(spec_path)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    if args.model != DEFAULT_MODEL:
        raise ValueError(f"The assignment requires {DEFAULT_MODEL} for every run.")

    rtl_best_practices = """
SystemVerilog RTL rules you must follow:
- Generate synthesizable SystemVerilog compatible with Icarus Verilog using -g2012.
- Use the exact module signature from the specification. Do not add, remove, rename, or resize ports.
- Prefer `logic` for internal data signals; use `int` for bounded loop indices when needed.
- Give each signal a single driver. Do not drive a signal from multiple procedural blocks.
- Use continuous `assign` statements for simple combinational expressions.
- Use `always_comb` for combinational decision logic. Do not write manual sensitivity lists.
- In every `always_comb` block, assign safe default values to every output or temporary written by that block before any `if` or `case`.
- Use blocking assignments (`=`) only in combinational logic.
- Use `always_ff` for clocked state. Use nonblocking assignments (`<=`) only in sequential logic.
- Do not mix blocking and nonblocking assignments in the same procedural block.
- Do not infer latches. Every output must receive a value for every valid input/control path.
- Use `unique case` or `case` with a `default` branch for decoders and operation selects.
- Do not use `casex`; avoid wildcard matching unless the spec requires it.
- Use explicit-width numeric literals, such as `32'h0000_0000`, `1'b0`, or `3'b101`.
- Avoid unsized constants in datapath expressions where width matters.
- For signed comparisons or arithmetic shifts, cast operands explicitly with `$signed(...)`.
- For logical right shifts use `>>`; for arithmetic right shifts use `>>>` with a signed left operand when needed.
- For shift amounts, use only the exact shift bits required by the spec.
- Keep purely combinational modules free of clocks, resets, initial blocks, delays, and state.
- For clocked modules, implement reset behavior exactly as described in the spec, including edge sensitivity and priority.
- Do not use `#` delays, `$display`, `$finish`, assertions, classes, randomization, DPI, interfaces, packages, macros, or non-synthesizable constructs in RTL.
- Prefer clear, direct RTL over clever or highly compressed code.
- The specification takes precedence over style preferences. Do not invent resets, bypasses, or unspecified features.
- Derive behavior, priorities, and default values from the supplied specification; do not assume a processor architecture or infer semantics from signal names alone.
- Check each specified operating mode and boundary condition against every affected output. Preserve explicitly unspecified behavior as implementation freedom, not an invented requirement.
- Return only the complete SystemVerilog module text, with no Markdown fences and no explanation.
""".strip()

    prompt_templates = {
        "direct": """
Generate synthesizable SystemVerilog RTL for `{top_module}`.

Specification:
{spec_text}
""".strip(),
        "rules_constraints": """
Generate RTL for the hardware design described below. Treat the YAML specification as the source of truth.

Before writing code, internally check these requirements:
1. The module signature is copied exactly.
2. Every behavior table and note in the spec is implemented.
3. Combinational and sequential logic use the correct SystemVerilog constructs.
4. Widths, signedness, reset timing, and illegal/default cases are handled explicitly.

RTL coding rules:
{rtl_best_practices}

Required module signature:
{module_signature}

Full specification:
{spec_text}
""".strip(),
        "template_fill": """
Complete the TODO in the module template below. Preserve the interface exactly
and replace the TODO with synthesizable SystemVerilog implementing the specification.

Module template:
{module_signature}
    // TODO: Declare internal signals and implement the specified behavior here.
endmodule

Full behavior specification:
{spec_text}
""".strip(),
    }

    # A1_PROMPT_STYLE selects the experiment style without editing the starter CLI.
    run_number = 1
    while True:
        run_dir = args.out_dir / f"{top_module}_{prompt_style}_run_{run_number:03d}"
        try:
            run_dir.mkdir()
            break
        except FileExistsError:
            run_number += 1
    for style, template in prompt_templates.items():
        write_file(run_dir / "templates" / f"{style}.txt", template + "\n")
    write_file(run_dir / "templates" / "rtl_best_practices.txt", rtl_best_practices + "\n")
    write_file(run_dir / "spec.yaml", spec_text)
    rtl_prompt = prompt_templates[prompt_style].format(
        top_module=top_module,
        module_signature=content.get("module_signature", "").strip(),
        spec_text=spec_text,
        rtl_best_practices=rtl_best_practices,
    )
    rtl_system_prompt = (
        "You are a senior digital design engineer generating small, synthesizable "
        "SystemVerilog RTL modules for an automated grading flow. Obey the user's "
        "module interface and output-format instructions exactly. Return only one "
        "complete SystemVerilog module, without Markdown or explanation."
    )

    write_file(run_dir / "system_prompt.txt", rtl_system_prompt)
    write_file(run_dir / f"{top_module}_{prompt_style}_rtl_prompt.txt", rtl_prompt)
    print(f"Generating run {run_number}: {run_dir}", flush=True)
    try:
        rtl_result = model.generate_full(rtl_prompt, system_prompt=rtl_system_prompt)
    except (Exception, SystemExit):
        write_file(run_dir / "status.txt", "generation: FAILED\ncompile: NOT_RUN\nsample_tests: NOT_RUN\n")
        raise
    write_file(run_dir / f"{top_module}_{prompt_style}_rtl_response.txt", rtl_result.content)
    write_file(
        run_dir / f"{top_module}_{prompt_style}_rtl_metadata.txt",
        "\n".join(
            [
                f"provider: {rtl_result.provider}",
                f"requested_model: {args.model}",
                f"returned_model: {rtl_result.model}",
                f"settings: {rtl_result.settings}",
                f"usage: {rtl_result.usage}",
                f"prompt_style: {prompt_style}",
                f"run: {run_number}",
            ]
        )
        + "\n",
    )

    rtl_code = strip_markdown_code_blocks(rtl_result.content)
    initial_rtl_path = run_dir / f"{top_module}_{prompt_style}_initial_rtl.sv"
    final_rtl_path = args.out_dir / "final_rtl.sv"
    write_file(initial_rtl_path, rtl_code + "\n")
    compile_ok, compile_output = run_iverilog_compile(
        initial_rtl_path, output_file=run_dir / "initial_rtl.vvp"
    )
    write_file(run_dir / "compile.log", compile_output + "\n")
    write_file(run_dir / "status.txt", f"compile: {'PASS' if compile_ok else 'FAIL'}\nsample_tests: NOT_RUN\n")
    print(f"Saved RTL prompt: {run_dir / f'{top_module}_{prompt_style}_rtl_prompt.txt'}")
    print(f"Saved initial RTL: {initial_rtl_path}")

    # <<< END STUDENT PHASE A CODE

    # ------------------------------------------------------------------
    # WORKFLOW PHASE B: GENERATE A TESTBENCH
    # Generate and save a self-checking testbench for the RTL. It should
    # exercise requirements and validation examples from the spec and report
    # results clearly enough for Phase C to interpret. Decide what design/spec
    # context to include in the prompt and how much coverage it should provide.
    #
    # >>> BEGIN STUDENT PHASE B CODE
    tb_system_prompt = (
        "You are a hardware verification engineer. Generate a standalone, "
        "self-checking SystemVerilog testbench from the supplied specification. "
        "Return only complete SystemVerilog code without Markdown or explanation. "
        "The specification defines expected behavior; never assume DUT behavior is correct."
    )
    tb_template = """
Write a testbench named {top_module}_tb for the hardware specified below.
Instantiate {top_module} with named port connections and preserve every port width
and declared bit index. Use only Icarus Verilog -g2012 compatible constructs.

Verification requirements:
- Derive expected results independently from the specification, not from DUT
  outputs or internal signals. Access the DUT only through its public ports.
- Cover every specified operation/mode, examples, boundary values, and priorities.
  Include zero, extrema, sign boundaries, and interacting controls when relevant.
- Check all specified outputs. Do not assert an arbitrary value for an output
  or input combination the specification leaves unspecified or permits to vary.
- Track which expected outputs are specified for each case. Compare only those
  outputs; do not turn an allowed implementation choice into an exact-value check.
- Infer whether the design is combinational or stateful from the specification.
  For combinational logic, allow a small nonzero settling delay before checking.
  For stateful logic, initialize through the specified interface, track expected
  state independently, drive away from active edges, and sample after nonblocking
  updates settle. Test reset timing and priority exactly as specified, if present.
- Use case inequality (!==) so unexpected X/Z values fail checks. Do not check
  uninitialized state unless its initial value is specified.
- Use deterministic bounded stimulus. Prefer directed cases plus systematic loops
  or a fixed-seed sequence; do not depend on simulator-default random seeds.
- Keep reference calculations explicit about widths and signedness. Account for
  arithmetic wraparound and exact index ranges where the specification requires it.
- Declare variables before statements in each scope. Avoid classes, packages,
  interfaces, SVA, external files, and unsupported constrained randomization.
- Never index a parenthesized arithmetic expression such as (i-1)[4:0].
  Assign it to a correctly sized temporary or use an explicit sized cast.
- For stateful tests, complete the specified initialization/reset event BEFORE
  checking state. Prefer a manually stepped clock so extra read checks cannot
  accidentally introduce unmodeled write/reset edges. Check before and after
  active edges without changing stimulus on the sampling edge.
- Include `timescale 1ns/1ps, initialize counters, and include an independent
  watchdog initial block that prints FAIL and calls $fatal(1, "timeout") if the
  main stimulus does not finish. Ensure the watchdog allows all planned tests.
- Count checks and failures. Print a diagnostic with inputs, actual and expected
  values for each mismatch. Print exactly SUMMARY checks=N failures=M on one
  line, replacing N and M with the decimal check and failure counts.
  Print a standalone PASS line only if checks > 0 and failures == 0, then $finish.
  Otherwise print FAIL and call $fatal(1, "verification failed").
- Include concise comments identifying the requirement groups being tested.
- Target at most 2500 output tokens, including all declarations and endmodule.
  Use compact reusable checking tasks and bounded loops instead of repeating
  long calls. Budget space for stimulus, final reporting, and the watchdog.

Required DUT interface:
{module_signature}

Full specification:
{spec_text}
""".strip()
    tb_prompt = tb_template.format(
        top_module=top_module,
        module_signature=content.get("module_signature", "").strip(),
        spec_text=spec_text,
    )
    write_file(run_dir / "templates" / "testbench.txt", tb_template + "\n")
    write_file(run_dir / "tb_system_prompt.txt", tb_system_prompt)
    write_file(run_dir / "tb_prompt.txt", tb_prompt)
    print(f"Generating testbench: {top_module}_tb", flush=True)
    try:
        tb_result = model.generate_full(tb_prompt, system_prompt=tb_system_prompt)
    except (Exception, SystemExit):
        write_file(run_dir / "tb_status.txt", "generation: FAILED\n")
        raise
    write_file(run_dir / "tb_response.txt", tb_result.content)
    write_file(
        run_dir / "tb_metadata.txt",
        "\n".join([
            f"provider: {tb_result.provider}",
            f"requested_model: {args.model}",
            f"returned_model: {tb_result.model}",
            f"settings: {tb_result.settings}",
            f"usage: {tb_result.usage}",
        ]) + "\n",
    )
    tb_code = strip_markdown_code_blocks(tb_result.content)
    tb_initial_path = run_dir / f"{top_module}_initial_tb.sv"
    write_file(tb_initial_path, tb_code + "\n")
    tb_compile_ok, tb_compile_output = run_iverilog_compile(
        initial_rtl_path, tb_initial_path, output_file=run_dir / "generated_tb.vvp"
    )
    write_file(run_dir / "tb_compile.log", tb_compile_output + "\n")
    write_file(run_dir / "tb_status.txt",
               f"compile: {'PASS' if tb_compile_ok else 'FAIL'}\nsimulation: NOT_RUN\n")
    print(f"Saved initial testbench: {tb_initial_path}")

    # <<< END STUDENT PHASE B CODE

    # ------------------------------------------------------------------
    # WORKFLOW PHASE C: SIMULATE AND ITERATIVELY REVISE
    # Compile the RTL and testbench with the provided
    # `run_iverilog_compile(...)` utility, run the result with `run_vvp(...)`,
    # and retain the diagnostics and simulation output. When compilation or
    # functional checks fail, use that feedback to revise the RTL, testbench,
    # or both, then compile and simulate again. Decide how to distinguish tool
    # execution success from functional success, use a finite stopping policy
    # (a maximum number of revision attempts), and preserve enough history to
    # explain what changed and why. The spec remains the source of truth when
    # deciding which artifact is incorrect.
    #
    # >>> BEGIN STUDENT PHASE C CODE
    from workflow_tools import TemporaryDirectory, result_passed, run_bounded, write_record

    max_repairs = 3
    package_root = Path(__file__).resolve().parents[1]
    sample_script = package_root / "module_packages" / top_module / "scripts" / f"run_{top_module}.sh"
    if not sample_script.is_file():
        raise RuntimeError(f"No instructor sample runner found: {sample_script}")
    history = {"max_repairs_per_artifact": max_repairs, "rtl": [], "tb": [],
               "status": "RUNNING", "sample_script": str(sample_script)}

    def save_generation(folder, result):
        write_record(folder / "generation.json", {
            "requested_model": args.model, "returned_model": result.model,
            "provider": result.provider, "settings": result.settings,
            "usage": result.usage, "raw": result.raw,
        })

    def truncation_note(result):
        reasons = [choice.get("finish_reason") for choice in result.raw.get("choices", [])]
        if "length" in reasons:
            return "Provider finish_reason=length: the response was truncated. Rewrite compactly; do not just append the missing tail."
        if "endmodule" not in result.content:
            return "The response has no endmodule; it may be incomplete. Return a complete, compact file."
        return "No provider truncation indication."

    def repair(kind, source, result, diagnostic, attempt, verified_rtl=None):
        folder = run_dir / f"{kind}_repair_{attempt:02d}"
        folder.mkdir()
        instructions = (
            "Repair only the RTL using the instructor sample diagnostics. Preserve the exact interface "
            "and all specified behavior. Generalize the correction across the input space; never "
            "hardcode test vectors. Where the spec permits implementation choices, use the "
            "sample expectations to select compatible defaults. Do not change the tests.\n" + rtl_best_practices
            if kind == "rtl" else
            "Repair only the testbench. The supplied RTL passed instructor samples, which is evidence "
            "but not proof of correctness. Reconcile diagnostics with the specification and retain "
            "independent expected values, meaningful coverage, and checks for all specified behavior. "
            "Never disable a valid failing check or copy DUT outputs into expected values. If a real "
            "RTL/spec discrepancy remains, keep reporting it. Do not change RTL.\n" + tb_prompt
        )
        prompt = (
            f"Repair attempt {attempt}/{max_repairs}.\n{instructions}\n\n"
            "Return the COMPLETE corrected file only. Keep it below 2500 tokens using compact "
            "tasks and loops. The response limit is unchanged.\n"
            f"Generation diagnostic: {truncation_note(result)}\n\n"
            f"Original specification:\n{spec_text}\n\nCurrent {kind}:\n{read_file(source)}\n\n"
            f"Tool commands, exit codes, and full diagnostics:\n{diagnostic}\n"
        )
        if verified_rtl is not None:
            prompt += f"\nSample-passing RTL, for interface/timing diagnosis only:\n{read_file(verified_rtl)}\n"
        system_prompt = rtl_system_prompt if kind == "rtl" else tb_system_prompt
        write_file(folder / "prompt.txt", prompt)
        write_file(folder / "system_prompt.txt", system_prompt)
        print(f"Repairing {kind}: attempt {attempt}/{max_repairs}", flush=True)
        try:
            response = model.generate_full(prompt, system_prompt=system_prompt)
        except (Exception, SystemExit):
            history["status"] = "API_ERROR"
            write_record(run_dir / "phase_c.json", history)
            write_file(folder / "error.txt", "Generation request failed; no revision produced.\n")
            raise
        write_file(folder / "response.txt", response.content)
        save_generation(folder, response)
        revised = folder / f"{top_module}_{kind}.sv"
        write_file(revised, strip_markdown_code_blocks(response.content) + "\n")
        return revised, response

    def record_check(kind, source, attempt, checks, passed):
        folder = run_dir / f"{kind}_check_{attempt:02d}"
        folder.mkdir()
        for name, check in checks.items():
            write_record(folder / f"{name}.json", check)
            write_file(folder / f"{name}.log", check["log"])
        entry = {"attempt": attempt, "source": str(source), "passed": passed,
                 "checks": checks}
        history[kind].append(entry)
        write_record(run_dir / "phase_c.json", history)
        print(f"{kind} attempt {attempt}: {'PASS' if passed else 'FAIL'}", flush=True)
        return "\n\n".join(
            f"Stage: {name}\nCommand: {check['command']}\n"
            f"Exit code: {check['exit_code']}\nTimed out: {check['timed_out']}\n"
            f"{check.get('interpretation', '')}\nLog:\n{check['log']}"
            for name, check in checks.items()
        )

    save_generation(run_dir, rtl_result)
    tb_generation_dir = run_dir / "tb_generation"
    tb_generation_dir.mkdir()
    save_generation(tb_generation_dir, tb_result)
    rtl_current, rtl_latest = initial_rtl_path, rtl_result
    rtl_passed = False
    # Build files stay off the remote filesystem. Source and diagnostic history persist.
    with TemporaryDirectory(prefix="a1-phase-c-") as temporary:
        build = Path(temporary)
        for attempt in range(max_repairs + 1):
            binary = build / f"rtl_{attempt}.vvp"
            compiled = run_bounded(["iverilog", "-g2012", "-s", top_module,
                                    "-o", binary, rtl_current.resolve()])
            checks = {"compile": compiled}
            if compiled["exit_code"] == 0 and not compiled["timed_out"]:
                samples = run_bounded(["bash", sample_script, rtl_current.resolve()],
                                      env={"BUILD_DIR": str(build / f"sample_{attempt}")})
                checks["samples"] = samples
                rtl_passed = result_passed(samples, sample=True)
            diagnostic = record_check("rtl", rtl_current, attempt, checks, rtl_passed)
            if rtl_passed:
                break
            if any(check.get("tool_error") or check["exit_code"] == 127 for check in checks.values()):
                break
            if attempt < max_repairs:
                rtl_current, rtl_latest = repair("rtl", rtl_current, rtl_latest, diagnostic, attempt + 1)

        if not rtl_passed:
            history["status"] = "RTL_UNRESOLVED"
            write_record(run_dir / "phase_c.json", history)
            raise SystemExit(f"RTL did not pass sample tests; see {run_dir / 'phase_c.json'}")

        write_file(run_dir / "verified_rtl.sv", read_file(rtl_current))
        tb_current, tb_latest = tb_initial_path, tb_result
        tb_passed = False
        for attempt in range(max_repairs + 1):
            binary = build / f"tb_{attempt}.vvp"
            compiled = run_bounded(["iverilog", "-g2012", "-s", f"{top_module}_tb",
                                    "-o", binary, rtl_current.resolve(), tb_current.resolve()])
            checks = {"compile": compiled}
            if compiled["exit_code"] == 0 and not compiled["timed_out"]:
                simulated = run_bounded(["vvp", binary])
                checks["simulation"] = simulated
                tb_passed = result_passed(simulated)
                if not tb_passed:
                    checks["simulation"]["interpretation"] = (
                        "Require exit 0, no timeout or failure diagnostics, standalone PASS, "
                        "and exactly one SUMMARY checks=N failures=0 with N > 0."
                    )
            diagnostic = record_check("tb", tb_current, attempt, checks, tb_passed)
            if tb_passed:
                break
            if any(check.get("tool_error") or check["exit_code"] == 127 for check in checks.values()):
                break
            if attempt < max_repairs:
                tb_current, tb_latest = repair("tb", tb_current, tb_latest, diagnostic,
                                               attempt + 1, verified_rtl=rtl_current)

    history["status"] = "PASS" if tb_passed else "TB_UNRESOLVED"
    history["verified_rtl"] = str(rtl_current)
    if tb_passed:
        write_file(run_dir / "verified_tb.sv", read_file(tb_current))
        write_file(final_rtl_path, read_file(rtl_current))
        write_file(args.out_dir / f"{top_module}_tb.sv", read_file(tb_current))
        history["verified_tb"] = str(tb_current)
        write_file(args.out_dir / "verified_run.txt", str(run_dir.resolve()) + "\n")
    write_record(run_dir / "phase_c.json", history)
    if not tb_passed:
        raise SystemExit(f"Testbench unresolved; RTL passed samples. See {run_dir / 'phase_c.json'}")
    print(f"Workflow PASS: {top_module}; history: {run_dir / 'phase_c.json'}")

    # <<< END STUDENT PHASE C CODE


if __name__ == "__main__":
    main()
