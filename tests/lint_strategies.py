from __future__ import annotations

import argparse
import hashlib
import re
import sys
from collections import defaultdict
from pathlib import Path


ALLOWED_CALLS = {
    "spawntower",
    "upgradetower",
    "clonetower",
    "toggleautoskip",
    "changetargets",
    "activateraisethedead",
    "brawlerreposition",
    "setdjtrack",
    "click",
    "send",
    "sleep",
    "selltower",
}


def strip_comment(line: str) -> str:
    # Current strategy commands do not use semicolons inside string arguments.
    return line.split(";", 1)[0].strip()


def balanced_parentheses(line: str) -> bool:
    depth = 0
    in_string = False
    escaped = False
    for character in line:
        if escaped:
            escaped = False
            continue
        if character == "\\" and in_string:
            escaped = True
            continue
        if character == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth < 0:
                return False
    return depth == 0 and not in_string


def lint_file(path: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    text = path.read_text(encoding="utf-8-sig")
    section = ""
    seen_sections: set[str] = set()
    step_count = 0

    for line_number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue

        section_match = re.fullmatch(r"\[([^\]]+)\]", line)
        if section_match:
            section = section_match.group(1).strip().lower()
            seen_sections.add(section)
            continue

        if section != "steps":
            continue

        step = strip_comment(line)
        if not step:
            continue
        step_count += 1

        if not balanced_parentheses(step):
            errors.append(f"{path.name}:{line_number}: unbalanced parentheses/quotes: {step}")
            continue

        if re.fullmatch(r"(?i)Commander\s*:=\s*true", step):
            continue

        call = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\(", step)
        if not call:
            errors.append(
                f"{path.name}:{line_number}: step is not in the strategy command grammar: {step}"
            )
            continue

        name = call.group(1).lower()
        if name not in ALLOWED_CALLS:
            errors.append(f"{path.name}:{line_number}: unsupported strategy command '{call.group(1)}'")

    if "steps" not in seen_sections:
        errors.append(f"{path.name}: missing [Steps] section")
    elif step_count == 0:
        warnings.append(f"{path.name}: [Steps] section is empty")

    if "settings" not in seen_sections:
        warnings.append(f"{path.name}: missing [Settings] section")

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    strategy_dir = root / "Resources" / "Strats"

    if not strategy_dir.is_dir():
        print(f"ERROR: strategy directory missing: {strategy_dir}")
        return 1

    files = sorted(strategy_dir.glob("*.strat"))
    if not files:
        print("ERROR: no .strat files found")
        return 1

    errors: list[str] = []
    warnings: list[str] = []
    hashes: dict[str, list[str]] = defaultdict(list)

    for path in files:
        file_errors, file_warnings = lint_file(path)
        errors.extend(file_errors)
        warnings.extend(file_warnings)
        hashes[hashlib.sha256(path.read_bytes()).hexdigest()].append(path.name)

    for names in hashes.values():
        if len(names) > 1:
            warnings.append("duplicate strategy contents: " + ", ".join(names))

    for warning in warnings:
        print(f"WARN: {warning}")
    for error in errors:
        print(f"ERROR: {error}")

    if errors:
        print(f"strategy lint: FAIL ({len(errors)} error(s), {len(warnings)} warning(s))")
        return 1

    print(f"strategy lint: PASS ({len(files)} files, {len(warnings)} warning(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
