from __future__ import annotations

import argparse
import re
import sys
import zipfile
from pathlib import Path

REQUIRED = {
    "Main.ahk",
    "LICENSE",
    "lib/Gdip_All.ahk",
    "lib/Gdip_ImageSearch.ahk",
    "lib/HyperSleep.ahk",
    "lib/ImageSearch/ImageSearch.ahk",
    "lib/Discord.ahk",
    "lib/OCR.ahk",
    "lib/JSON.ahk",
    "lib/Roblox.ahk",
    "lib/RuntimeLog.ahk",
    "lib/auto_settings.ahk",
    "submacros/updater.ahk",
    "submacros/safe_update.ps1",
    "submacros/watchdog.ahk",
}

FORBIDDEN_PARTS = {
    ".git",
    ".github",
    ".pytest_cache",
    "__pycache__",
    "dist",
    "docs",
    "tests",
    "tools",
}

FORBIDDEN_SUFFIXES = {
    ".bak",
    ".bat",
    ".log",
    ".md",
    ".pdb",
    ".psd",
    ".py",
    ".pyc",
    ".tmp",
    ".toml",
    ".yaml",
    ".yml",
}

VERSION_RE = re.compile(r'(?m)^\s*ver\s*:=\s*"([^"]+)"\s*$')


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate a built Ultimate Macro release ZIP.")
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--zip", dest="zip_path", default="dist/TDS_Macro.zip")
    return parser.parse_args()


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    package = Path(args.zip_path)
    if not package.is_absolute():
        package = root / package

    errors: list[str] = []
    if package.name != "TDS_Macro.zip":
        fail(errors, f"release asset must be named TDS_Macro.zip, got {package.name}")
    if not package.is_file():
        fail(errors, f"release package is missing: {package}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    version = (root / "VERSION").read_text(encoding="utf-8-sig").strip()
    main_source = (root / "Main.ahk").read_text(encoding="utf-8-sig", errors="replace")
    match = VERSION_RE.search(main_source)
    if not match or match.group(1) != version:
        fail(errors, "VERSION does not match Main.ahk")

    try:
        with zipfile.ZipFile(package) as archive:
            names = archive.namelist()
            normalized = {name.replace("\\", "/") for name in names}

            missing = sorted(REQUIRED - normalized)
            for path in missing:
                fail(errors, f"required runtime file missing from release: {path}")

            for name in names:
                relative = Path(name)
                parts = {part.casefold() for part in relative.parts}
                if parts & FORBIDDEN_PARTS:
                    fail(errors, f"developer-only path leaked into release: {name}")
                if relative.suffix.casefold() in FORBIDDEN_SUFFIXES:
                    fail(errors, f"developer-only file leaked into release: {name}")
                if relative.name.casefold().startswith(".git"):
                    fail(errors, f"Git metadata leaked into release: {name}")

            if "submacros/update.bat" in normalized:
                fail(errors, "legacy batch updater wrapper must not ship")

            if (root / "StrategyLab.exe").is_file() and "StrategyLab.exe" not in normalized:
                fail(errors, "StrategyLab.exe exists in source but is missing from release")

            if (root / "_app").is_dir():
                packaged_app = [name for name in normalized if name.startswith("_app/")]
                if not packaged_app:
                    fail(errors, "_app runtime exists in source but was not packaged")
    except zipfile.BadZipFile:
        fail(errors, "release package is not a valid ZIP")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print(f"release package validation passed: {package}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
