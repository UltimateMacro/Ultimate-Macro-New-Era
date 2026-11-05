#!/usr/bin/env python3
"""Check engine/engine-manifest.json against the files in engine/.

Fails if a listed file is missing or its SHA-256 differs from the manifest.
Files present in engine/ but not listed are reported as warnings only.
"""
import hashlib
import json
import sys
from pathlib import Path

ENGINE = Path("engine")
MANIFEST = ENGINE / "engine-manifest.json"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8-sig"))
    files = manifest.get("files")
    if not isinstance(files, dict) or not files:
        print(f"::error file={MANIFEST}::manifest has no 'files' table")
        return 1

    errors = 0
    for rel, expected in sorted(files.items()):
        path = ENGINE / rel
        if not path.is_file():
            print(f"::error file={MANIFEST}::listed file is missing: engine/{rel}")
            errors += 1
        elif sha256(path) != expected.lower():
            print(f"::error file=engine/{rel}::SHA-256 does not match engine-manifest.json")
            errors += 1

    listed = set(files)
    for path in sorted(p for p in ENGINE.rglob("*") if p.is_file()):
        rel = path.relative_to(ENGINE).as_posix()
        if rel not in listed and rel != MANIFEST.name:
            print(f"::warning file=engine/{rel}::file is not listed in engine-manifest.json")

    if errors:
        print(f"{errors} manifest problem(s) found")
        return 1
    print(f"engine manifest OK ({len(files)} files verified)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
