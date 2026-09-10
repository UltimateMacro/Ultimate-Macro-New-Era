from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

REQUIRED = {
    "Main.ahk",
    "README.md",
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

COMMENT_REDUCTION_TARGETS = (
    ("Main.ahk", ";"),
    ("submacros/watchdog.ahk", ";"),
    ("submacros/safe_update.ps1", "#"),
    ("_app/ui/app.js", "//"),
)

UNCHANGED_THIRD_PARTY = (
    "lib/Gdip_All.ahk",
    "lib/Gdip_ImageSearch.ahk",
    "lib/ImageSearch/ImageSearch.ahk",
    "lib/OCR.ahk",
    "lib/JSON.ahk",
    "lib/ImageSearch/image_search.dll",
)

AHK_PACKAGE_VALIDATION_TARGETS = (
    "Main.ahk",
    "submacros/watchdog.ahk",
    "submacros/auto_ability.ahk",
    "submacros/auto_open_consumable.ahk",
    "submacros/auto_spin.ahk",
)

VERSION_RE = re.compile(r'(?m)^\s*ver\s*:=\s*"([^"]+)"\s*$')


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate a built Ultimate Macro release ZIP.")
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--zip", dest="zip_path", default="dist/TDS_Macro.zip")
    return parser.parse_args()


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def leading_comment_header(text: str, prefix: str) -> str:
    lines = text.splitlines(keepends=True)
    end = 0
    saw_comment = False

    for index, line in enumerate(lines):
        stripped = line.lstrip()
        if not stripped.strip():
            if saw_comment:
                end = index + 1
            continue
        if stripped.startswith(prefix):
            if prefix == "#" and stripped.casefold().startswith("#requires"):
                break
            saw_comment = True
            end = index + 1
            continue
        break

    return "".join(lines[:end]) if saw_comment else ""


def normalized_newlines(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def comment_only_count(text: str, prefix: str) -> int:
    count = 0
    for line in text.splitlines():
        stripped = line.lstrip()
        if prefix == "//":
            if stripped.startswith("//"):
                count += 1
        elif stripped.startswith(prefix):
            if prefix == "#" and stripped.casefold().startswith("#requires"):
                continue
            count += 1
    return count


def validate_packaged_ahk(extract_root: Path, errors: list[str]) -> None:
    if os.name != "nt":
        return

    auto_hotkey = extract_root / "submacros" / "AutoHotkey64.exe"
    if not auto_hotkey.is_file():
        fail(errors, "packaged AutoHotkey64.exe is missing; cannot validate stripped scripts")
        return

    for relative in AHK_PACKAGE_VALIDATION_TARGETS:
        script = extract_root / relative
        if not script.is_file():
            fail(errors, f"packaged AHK validation target is missing: {relative}")
            continue

        try:
            completed = subprocess.run(
                [
                    str(auto_hotkey),
                    "/ErrorStdOut=UTF-8",
                    "/Validate",
                    str(script),
                ],
                cwd=extract_root,
                capture_output=True,
                text=True,
                timeout=20,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            fail(errors, f"packaged AutoHotkey validation could not run for {relative}: {exc}")
            continue

        if completed.returncode != 0:
            output = (completed.stdout + "\n" + completed.stderr).strip()
            fail(
                errors,
                f"packaged AutoHotkey validation failed for {relative}: {output}",
            )


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
                normalized_name = name.replace("\\", "/")
                if (
                    normalized_name.startswith("/")
                    or re.match(r"^[A-Za-z]:", normalized_name)
                    or ".." in Path(normalized_name).parts
                ):
                    fail(errors, f"unsafe ZIP entry: {name}")
                if parts & FORBIDDEN_PARTS:
                    fail(errors, f"developer-only path leaked into release: {name}")
                if (
                    relative.suffix.casefold() in FORBIDDEN_SUFFIXES
                    and relative.as_posix().casefold() != "readme.md"
                ):
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

            if "Main.ahk" in normalized:
                packaged_main = archive.read("Main.ahk").decode("utf-8-sig", errors="replace")
                expected_header = leading_comment_header(main_source, ";")
                if expected_header and not normalized_newlines(packaged_main).startswith(
                    normalized_newlines(expected_header)
                ):
                    fail(errors, "Main.ahk attribution/header comments must remain intact")

            for relative, prefix in COMMENT_REDUCTION_TARGETS:
                source_path = root / relative
                if not source_path.is_file() or relative not in normalized:
                    continue
                source_text = source_path.read_text(encoding="utf-8-sig", errors="replace")
                packaged_text = archive.read(relative).decode("utf-8-sig", errors="replace")
                source_count = comment_only_count(source_text, prefix)
                packaged_count = comment_only_count(packaged_text, prefix)
                if source_count > 0 and packaged_count >= source_count:
                    fail(
                        errors,
                        f"nonessential comments were not reduced in packaged script: {relative}",
                    )

            for relative in UNCHANGED_THIRD_PARTY:
                source_path = root / relative
                if source_path.is_file() and relative in normalized:
                    if archive.read(relative) != source_path.read_bytes():
                        fail(
                            errors,
                            f"third-party/binary dependency was modified during packaging: {relative}",
                        )

            if not errors and os.name == "nt":
                with tempfile.TemporaryDirectory(prefix="ultimate-macro-package-") as temp_dir:
                    extract_root = Path(temp_dir)
                    archive.extractall(extract_root)
                    validate_packaged_ahk(extract_root, errors)
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
