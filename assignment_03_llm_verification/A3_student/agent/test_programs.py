"""Structured RV32I test parsing, encoding, and deterministic safety-net tests."""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "reference"
if str(REFERENCE) not in sys.path:
    sys.path.insert(0, str(REFERENCE))

import rv32i_isa as isa  # noqa: E402
from iss import ISS  # noqa: E402


REGISTER_OPS = {"ADD", "SUB", "SLL", "SLT", "SLTU", "XOR", "SRL", "SRA", "OR", "AND"}
IMMEDIATE_OPS = {"ADDI", "SLTI", "SLTIU", "XORI", "ORI", "ANDI"}
SHIFT_OPS = {"SLLI", "SRLI", "SRAI"}
LOAD_OPS = {"LB", "LH", "LW", "LBU", "LHU"}
STORE_OPS = {"SB", "SH", "SW"}
BRANCH_OPS = {"BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU"}
UPPER_OPS = {"LUI", "AUIPC"}
JUMP_OPS = {"JAL", "JALR"}
ALLOWED_OPS = REGISTER_OPS | IMMEDIATE_OPS | SHIFT_OPS | LOAD_OPS | STORE_OPS | BRANCH_OPS | UPPER_OPS | JUMP_OPS
TARGET_FAMILIES = {
    "forwarding",
    "x0_integrity",
    "load_use",
    "flush_redirect",
    "branch_jump_target",
    "coverage",
}


@dataclass
class TestProgram:
    name: str
    target_family: str
    description: str
    signature_reg: int
    instructions: List[Dict[str, Any]]
    words: List[int]
    expected_signature: int
    origin: str

    def manifest_entry(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "target_family": self.target_family,
            "description": self.description,
            "signature_reg": self.signature_reg,
            "instructions": self.instructions,
            "word_count": len(self.words),
            "expected_signature": f"0x{self.expected_signature:08x}",
            "origin": self.origin,
        }


def _integer(value: Any, label: str) -> int:
    if isinstance(value, bool):
        raise ValueError(f"{label} must be an integer")
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        try:
            return int(value, 0)
        except ValueError as error:
            raise ValueError(f"{label} is not an integer: {value!r}") from error
    raise ValueError(f"{label} must be an integer")


def _register(value: Any, label: str) -> int:
    reg = _integer(value, label)
    if not 0 <= reg <= 31:
        raise ValueError(f"{label} register must be between 0 and 31")
    return reg


def _signed_immediate(value: Any, bits: int, label: str, even: bool = False) -> int:
    imm = _integer(value, label)
    if not -(1 << (bits - 1)) <= imm <= (1 << (bits - 1)) - 1:
        raise ValueError(f"{label} must fit signed {bits} bits")
    if even and imm % 2:
        raise ValueError(f"{label} must be even")
    return imm


def encode_instruction(item: Dict[str, Any]) -> int:
    if not isinstance(item, dict):
        raise ValueError("each instruction must be an object")
    op = str(item.get("op", "")).upper().strip()
    args = item.get("args")
    if op not in ALLOWED_OPS:
        raise ValueError(f"unsupported operation {op!r}")
    if not isinstance(args, list):
        raise ValueError(f"{op} args must be a list")

    if op in REGISTER_OPS:
        if len(args) != 3:
            raise ValueError(f"{op} requires [rd, rs1, rs2]")
        parsed = [_register(args[0], "rd"), _register(args[1], "rs1"), _register(args[2], "rs2")]
    elif op in IMMEDIATE_OPS:
        if len(args) != 3:
            raise ValueError(f"{op} requires [rd, rs1, imm]")
        parsed = [_register(args[0], "rd"), _register(args[1], "rs1"), _signed_immediate(args[2], 12, "immediate")]
    elif op in SHIFT_OPS:
        if len(args) != 3:
            raise ValueError(f"{op} requires [rd, rs1, shamt]")
        shamt = _integer(args[2], "shift amount")
        if not 0 <= shamt <= 31:
            raise ValueError("shift amount must be between 0 and 31")
        parsed = [_register(args[0], "rd"), _register(args[1], "rs1"), shamt]
    elif op in LOAD_OPS:
        if len(args) != 3:
            raise ValueError(f"{op} requires [rd, base_rs1, offset]")
        parsed = [_register(args[0], "rd"), _register(args[1], "base_rs1"), _signed_immediate(args[2], 12, "load offset")]
    elif op in STORE_OPS:
        if len(args) != 3:
            raise ValueError(f"{op} requires [base_rs1, value_rs2, offset]")
        parsed = [_register(args[0], "base_rs1"), _register(args[1], "value_rs2"), _signed_immediate(args[2], 12, "store offset")]
    elif op in BRANCH_OPS:
        if len(args) != 3:
            raise ValueError(f"{op} requires [rs1, rs2, pc_relative_offset]")
        parsed = [_register(args[0], "rs1"), _register(args[1], "rs2"), _signed_immediate(args[2], 13, "branch offset", even=True)]
    elif op in UPPER_OPS:
        if len(args) != 2:
            raise ValueError(f"{op} requires [rd, upper_immediate]")
        immediate = _integer(args[1], "upper immediate")
        if immediate & 0xFFF:
            raise ValueError(f"{op} immediate must have its low 12 bits clear")
        parsed = [_register(args[0], "rd"), immediate]
    elif op == "JAL":
        if len(args) != 2:
            raise ValueError("JAL requires [rd, pc_relative_offset]")
        parsed = [_register(args[0], "rd"), _signed_immediate(args[1], 21, "JAL offset", even=True)]
    else:
        if len(args) != 3:
            raise ValueError("JALR requires [rd, base_rs1, offset]")
        parsed = [_register(args[0], "rd"), _register(args[1], "base_rs1"), _signed_immediate(args[2], 12, "JALR offset")]

    return int(getattr(isa, op)(*parsed)) & 0xFFFFFFFF


def _signature_epilogue(signature_reg: int) -> Tuple[List[Dict[str, Any]], List[int]]:
    instructions = [
        {"op": "LUI", "args": [31, 0]},
        {"op": "ADDI", "args": [31, 31, 0x100]},
        {"op": "SW", "args": [31, signature_reg, 0]},
    ]
    return instructions, [encode_instruction(item) for item in instructions]


def build_test(entry: Dict[str, Any], origin: str) -> TestProgram:
    if not isinstance(entry, dict):
        raise ValueError("test entry must be an object")
    raw_name = str(entry.get("name", "")).strip().lower()
    name = re.sub(r"[^a-z0-9_]+", "_", raw_name).strip("_")
    if not name or len(name) > 64:
        raise ValueError("test name must contain 1-64 letters, digits, or underscores")
    family = str(entry.get("target_family", "")).strip().lower()
    if family not in TARGET_FAMILIES:
        raise ValueError(f"target_family must be one of {sorted(TARGET_FAMILIES)}")
    description = str(entry.get("description", "")).strip()
    if not description:
        raise ValueError("description is required")
    signature_reg = _register(entry.get("signature_reg"), "signature_reg")
    if signature_reg in {0, 31}:
        raise ValueError("signature_reg must be x1-x30; x31 is reserved for address 0x100")

    body = entry.get("instructions")
    if not isinstance(body, list) or not 1 <= len(body) <= 96:
        raise ValueError("instructions must contain 1-96 instruction objects")
    normalized: List[Dict[str, Any]] = []
    words: List[int] = []
    for index, instruction in enumerate(body):
        if not isinstance(instruction, dict):
            raise ValueError(f"instruction {index} must be an object")
        normalized_item = {"op": str(instruction.get("op", "")).upper().strip(), "args": instruction.get("args")}
        try:
            word = encode_instruction(normalized_item)
        except ValueError as error:
            raise ValueError(f"instruction {index}: {error}") from error
        normalized.append(normalized_item)
        words.append(word)

    epilogue_instructions, epilogue_words = _signature_epilogue(signature_reg)
    all_words = words + epilogue_words
    _, signature = ISS(all_words, max_steps=10000).run()
    if signature is None:
        raise ValueError("program does not reach the automatically appended signature store")
    return TestProgram(name, family, description, signature_reg, normalized + epilogue_instructions,
                       all_words, signature, origin)


def extract_json(text: str) -> Dict[str, Any]:
    fenced = re.findall(r"```(?:json)?\s*(.*?)```", text, flags=re.DOTALL | re.IGNORECASE)
    candidate = fenced[-1].strip() if fenced else text.strip()
    start, end = candidate.find("{"), candidate.rfind("}")
    if start < 0 or end < start:
        raise ValueError("response does not contain a JSON object")
    parsed = json.loads(candidate[start:end + 1])
    if not isinstance(parsed, dict):
        raise ValueError("top-level response must be a JSON object")
    return parsed


def parse_generated_tests(text: str, origin: str) -> Tuple[List[TestProgram], List[str]]:
    entries = extract_json(text).get("tests")
    if not isinstance(entries, list):
        raise ValueError("top-level 'tests' must be a list")
    valid: List[TestProgram] = []
    errors: List[str] = []
    seen = set()
    for index, entry in enumerate(entries):
        try:
            test = build_test(entry, origin=origin)
            if test.name in seen:
                raise ValueError(f"duplicate test name {test.name!r}")
            seen.add(test.name)
            valid.append(test)
        except (ValueError, TypeError) as error:
            errors.append(f"test[{index}]: {error}")
    return valid, errors


def write_tests(tests: Iterable[TestProgram], tests_dir: Path) -> None:
    tests_dir.mkdir(parents=True, exist_ok=True)
    for test in tests:
        (tests_dir / f"{test.name}.hex").write_text(
            "".join(f"{word:08x}\n" for word in test.words), encoding="utf-8"
        )


def load_manifest_tests(tests_dir: Path, manifest_path: Path) -> List[TestProgram]:
    """Reconstruct the current suite without asking the model to regenerate Task 2."""
    if not manifest_path.is_file():
        raise ValueError(f"test manifest is missing: {manifest_path}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read test manifest: {error}") from error
    entries = manifest.get("tests")
    if not isinstance(entries, list) or not entries:
        raise ValueError("test manifest contains no tests")

    tests: List[TestProgram] = []
    seen = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise ValueError(f"manifest test[{index}] must be an object")
        name = str(entry.get("name", ""))
        if not name or name in seen:
            raise ValueError(f"manifest test[{index}] has an invalid or duplicate name")
        seen.add(name)
        hex_path = tests_dir / f"{name}.hex"
        if not hex_path.is_file():
            raise ValueError(f"manifest test file is missing: {hex_path}")
        try:
            words = [int(line.strip(), 16) & 0xFFFFFFFF
                     for line in hex_path.read_text(encoding="utf-8").splitlines()
                     if line.strip()]
        except ValueError as error:
            raise ValueError(f"invalid hex in {hex_path}: {error}") from error
        _, signature = ISS(words, max_steps=10000).run()
        if signature is None:
            raise ValueError(f"test does not reach a signature store: {hex_path}")
        family = str(entry.get("target_family", "coverage"))
        instructions = entry.get("instructions", [])
        tests.append(TestProgram(
            name=name,
            target_family=family,
            description=str(entry.get("description", "Loaded from the saved manifest.")),
            signature_reg=_register(entry.get("signature_reg"), "signature_reg"),
            instructions=instructions if isinstance(instructions, list) else [],
            words=words,
            expected_signature=signature,
            origin=str(entry.get("origin", "saved_manifest")),
        ))
    return tests


def seed_tests() -> List[TestProgram]:
    entries = [
        {"name": "seed_forwarding_priority", "target_family": "forwarding",
         "description": "Two in-flight writers require the fresher Memory-stage value.", "signature_reg": 2,
         "instructions": [{"op": "ADDI", "args": [1, 0, 5]}, {"op": "ADDI", "args": [1, 1, 7]}, {"op": "ADD", "args": [2, 1, 0]}]},
        {"name": "seed_forwarding_both_operands", "target_family": "forwarding",
         "description": "Exercises forwarding through both source operands at Memory and Writeback distances.", "signature_reg": 6,
         "instructions": [{"op": "ADDI", "args": [3, 0, 9]}, {"op": "ADD", "args": [4, 3, 3]}, {"op": "ADDI", "args": [0, 0, 0]}, {"op": "ADD", "args": [5, 4, 4]}, {"op": "ADD", "args": [6, 5, 3]}]},
        {"name": "seed_x0_integrity", "target_family": "x0_integrity",
         "description": "A nonzero result addressed to x0 must not be forwarded.", "signature_reg": 5,
         "instructions": [{"op": "ADDI", "args": [0, 0, 123]}, {"op": "ADDI", "args": [5, 0, 1]}]},
        {"name": "seed_load_use_rs1", "target_family": "load_use",
         "description": "An LW is immediately consumed through rs1.", "signature_reg": 8,
         "instructions": [{"op": "ADDI", "args": [10, 0, 64]}, {"op": "ADDI", "args": [6, 0, 42]}, {"op": "SW", "args": [10, 6, 0]}, {"op": "LW", "args": [7, 10, 0]}, {"op": "ADDI", "args": [8, 7, 1]}]},
        {"name": "seed_load_use_rs2", "target_family": "load_use",
         "description": "An LW is immediately consumed through rs2.", "signature_reg": 8,
         "instructions": [{"op": "ADDI", "args": [10, 0, 64]}, {"op": "ADDI", "args": [6, 0, 50]}, {"op": "ADDI", "args": [9, 0, 10]}, {"op": "SW", "args": [10, 9, 0]}, {"op": "LW", "args": [7, 10, 0]}, {"op": "ADD", "args": [8, 6, 7]}]},
        {"name": "seed_taken_branch_flush", "target_family": "flush_redirect",
         "description": "A taken branch must squash a wrong-path value consumed at the target.", "signature_reg": 3,
         "instructions": [{"op": "ADDI", "args": [1, 0, 1]}, {"op": "BEQ", "args": [1, 1, 8]}, {"op": "ADDI", "args": [2, 0, 99]}, {"op": "ADDI", "args": [3, 2, 1]}]},
        {"name": "seed_jal_flush", "target_family": "flush_redirect",
         "description": "JAL redirects over a wrong-path producer consumed at the target.", "signature_reg": 3,
         "instructions": [{"op": "JAL", "args": [5, 8]}, {"op": "ADDI", "args": [2, 0, 99]}, {"op": "ADDI", "args": [3, 2, 1]}]},
        {"name": "seed_jalr_odd_target", "target_family": "branch_jump_target",
         "description": "JALR must clear target bit zero; a target JAL link exposes an odd PC.", "signature_reg": 3,
         "instructions": [{"op": "ADDI", "args": [1, 0, 13]}, {"op": "JALR", "args": [5, 1, 0]}, {"op": "ADDI", "args": [2, 0, 99]}, {"op": "JAL", "args": [2, 4]}, {"op": "ADDI", "args": [3, 2, 0]}]},
    ]
    return [build_test(entry, origin="deterministic_seed") for entry in entries]
