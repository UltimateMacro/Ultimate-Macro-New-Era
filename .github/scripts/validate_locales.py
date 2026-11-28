#!/usr/bin/env python3
"""Validate the community locale catalogs in assets/locales/*.json.

Each catalog must be valid JSON shaped like:
  {"schema": 1, "locale": "<file stem>", "nativeName": "...",
   "translations": {"English phrase": "Translated phrase", ...}}
"""
import json
import sys
from pathlib import Path

LOCALES = Path("assets/locales")


def check(path: Path) -> list[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as exc:
        return [f"not valid JSON: {exc}"]
    if not isinstance(data, dict):
        return ["top level must be an object"]

    problems = []
    if data.get("schema") != 1:
        problems.append("'schema' must be 1")
    if data.get("locale") != path.stem:
        problems.append(f"'locale' must be '{path.stem}' (found {data.get('locale')!r})")
    if not isinstance(data.get("nativeName"), str) or not data["nativeName"].strip():
        problems.append("'nativeName' must be a non-empty string")
    translations = data.get("translations")
    if not isinstance(translations, dict) or not translations:
        problems.append("'translations' must be a non-empty object")
    else:
        for key, value in translations.items():
            if not isinstance(value, str):
                problems.append(f"translation for {key!r} must be a string")
    return problems


def main() -> int:
    paths = sorted(LOCALES.glob("*.json"))
    if not paths:
        print(f"::error::no locale files found in {LOCALES}")
        return 1

    failed = 0
    for path in paths:
        problems = check(path)
        for problem in problems:
            print(f"::error file={path}::{problem}")
        failed += bool(problems)
    if failed:
        print(f"{failed} of {len(paths)} locale file(s) failed validation")
        return 1
    print(f"all {len(paths)} locale files OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
