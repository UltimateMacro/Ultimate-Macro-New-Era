#!/usr/bin/env python3
"""Validate the language catalogs in Resources/Languages/*.json.

TranslationTemplate.json lists every English string. Each locale file must be
valid JSON shaped like:
  {"Locale": "<file stem>", "Name": "...",
   "Strings": {"English phrase": "Translated phrase", ...}}

Empty values are allowed (the macro falls back to English). Keys missing from,
or not in, the template are reported as warnings so translators can catch up.
"""
import json
import sys
from pathlib import Path

LANGUAGES = Path("Resources/Languages")
TEMPLATE = LANGUAGES / "TranslationTemplate.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def strings_problems(strings) -> list[str]:
    if not isinstance(strings, dict) or not strings:
        return ["'Strings' must be a non-empty object"]
    return [f"value for {key!r} must be a string" for key, value in strings.items() if not isinstance(value, str)]


def main() -> int:
    try:
        template = load(TEMPLATE)
    except (OSError, ValueError) as exc:
        print(f"::error file={TEMPLATE}::cannot read template: {exc}")
        return 1
    problems = strings_problems(template.get("Strings") if isinstance(template, dict) else None)
    for problem in problems:
        print(f"::error file={TEMPLATE}::{problem}")
    if problems:
        return 1
    keys = set(template["Strings"])

    paths = sorted(p for p in LANGUAGES.glob("*.json") if p != TEMPLATE)
    if not paths:
        print(f"::error::no locale files found in {LANGUAGES}")
        return 1

    failed = 0
    for path in paths:
        try:
            data = load(path)
        except (OSError, ValueError) as exc:
            print(f"::error file={path}::not valid JSON: {exc}")
            failed += 1
            continue
        if not isinstance(data, dict):
            print(f"::error file={path}::top level must be an object")
            failed += 1
            continue

        problems = []
        if data.get("Locale") != path.stem:
            problems.append(f"'Locale' must be '{path.stem}' (found {data.get('Locale')!r})")
        if not isinstance(data.get("Name"), str) or not data["Name"].strip():
            problems.append("'Name' must be a non-empty string")
        problems += strings_problems(data.get("Strings"))
        for problem in problems:
            print(f"::error file={path}::{problem}")
        failed += bool(problems)

        if not problems:
            have = set(data["Strings"])
            missing, extra = len(keys - have), len(have - keys)
            if missing:
                print(f"::warning file={path}::{missing} template string(s) missing (shown in English)")
            if extra:
                print(f"::warning file={path}::{extra} string(s) not in TranslationTemplate.json")

    if failed:
        print(f"{failed} of {len(paths)} locale file(s) failed validation")
        return 1
    print(f"all {len(paths)} locale files OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
