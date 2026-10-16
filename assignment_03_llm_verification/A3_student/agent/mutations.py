"""Representative self-mutations for the five Task 2 bug families."""

from __future__ import annotations

import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

from rtl_runner import discover_core, run_suite
from test_programs import TestProgram


@dataclass(frozen=True)
class Mutation:
    name: str
    family: str
    description: str
    old: str
    new: str


MUTATIONS = [
    Mutation(
        "forwarding_priority_reversed",
        "forwarding",
        "Give Writeback priority over a fresher matching Memory-stage producer for source A.",
        """        if (RegWriteM && (RdM != 5'b0) && (RdM == Rs1E))
            ForwardAE = 2'b10;
        else if (RegWriteW && (RdW != 5'b0) && (RdW == Rs1E))
            ForwardAE = 2'b01;""",
        """        if (RegWriteW && (RdW != 5'b0) && (RdW == Rs1E))
            ForwardAE = 2'b01;
        else if (RegWriteM && (RdM != 5'b0) && (RdM == Rs1E))
            ForwardAE = 2'b10;""",
    ),
    Mutation(
        "x0_forwarding_guard_removed",
        "x0_integrity",
        "Allow a Memory-stage instruction addressed to x0 to forward a nonzero internal result.",
        "if (RegWriteM && (RdM != 5'b0) && (RdM == Rs1E))",
        "if (RegWriteM && (RdM == Rs1E))",
    ),
    Mutation(
        "load_use_stall_disabled",
        "load_use",
        "Disable load-use hazard detection.",
        """    assign LoadUseHazard = (ResultSrcE == 3'b001) &&
                           (RdE != 5'b0) &&
                           ((RdE == Rs1D) || (RdE == Rs2D));""",
        "    assign LoadUseHazard = 1'b0;",
    ),
    Mutation(
        "redirect_execute_flush_disabled",
        "flush_redirect",
        "Do not flush the Decode instruction entering Execute after a redirect.",
        "    assign FlushE    = RedirectE || LoadUseHazard;",
        "    assign FlushE    = LoadUseHazard;",
    ),
    Mutation(
        "jalr_low_bit_not_cleared",
        "branch_jump_target",
        "Use the raw odd JALR sum instead of clearing target bit zero.",
        "    assign RedirectTargetE = (JumpE && OpcodeE == 7'b1100111) ? {SumE[31:1],1'b0} : SumE;",
        "    assign RedirectTargetE = SumE;",
    ),
]


def create_mutant(base_core: Path, mutant_parent: Path, mutation: Mutation) -> Path:
    sources = discover_core(base_core)
    mutant_core = mutant_parent / mutation.name / "core"
    if mutant_core.exists():
        shutil.rmtree(mutant_core)
    shutil.copytree(sources.directory, mutant_core)
    relative_datapath = sources.datapath.relative_to(sources.directory)
    mutant_datapath = mutant_core / relative_datapath
    text = mutant_datapath.read_text(encoding="utf-8")
    occurrences = text.count(mutation.old)
    if occurrences != 1:
        raise ValueError(
            f"mutation {mutation.name} expected one source pattern, found {occurrences}"
        )
    mutant_datapath.write_text(text.replace(mutation.old, mutation.new, 1), encoding="utf-8")
    return mutant_core


def run_mutations(base_core: Path, tests: List[TestProgram], mutant_parent: Path) -> Dict[str, object]:
    mutant_parent.mkdir(parents=True, exist_ok=True)
    records = []
    for mutation in MUTATIONS:
        record: Dict[str, object] = {
            "name": mutation.name,
            "family": mutation.family,
            "description": mutation.description,
        }
        try:
            mutant_core = create_mutant(base_core, mutant_parent, mutation)
            result = run_suite(mutant_core, tests)
            detecting_tests = [entry["name"] for entry in result["tests"] if entry["status"] == "fail"]
            record.update({
                "mutation_status": "valid" if result["compile"]["status"] == "pass" else "invalid",
                "detected": bool(detecting_tests),
                "detecting_tests": detecting_tests,
                "suite_result": result,
            })
        except Exception as error:
            record.update({"mutation_status": "error", "detected": False, "error": str(error)})
        records.append(record)
    missed = [record["family"] for record in records if not record.get("detected")]
    return {
        "mutations": records,
        "families_detected": sorted({record["family"] for record in records if record.get("detected")}),
        "families_missed": sorted(set(missed)),
    }
