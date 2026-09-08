from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path

ROOT_FILES = (
    "Main.ahk",
    "icon.ico",
    "LICENSE",
)

OPTIONAL_ROOT_FILES = (
    "StrategyLab.exe",
)

RUNTIME_ROOTS = (
    "Resources",
    "lib",
    "submacros",
    "_app",
)

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

FORBIDDEN_NAMES = {
    "state.ini",
    "overall_stats.ini",
    "run_ledger.csv",
}

VERSION_RE = re.compile(r'(?m)^\s*ver\s*:=\s*"([^"]+)"\s*$')


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build a clean Ultimate Macro release ZIP.")
    parser.add_argument("root", nargs="?", default=".", help="repository root")
    parser.add_argument(
        "--output",
        default="dist/TDS_Macro.zip",
        help="output ZIP path, relative to root unless absolute",
    )
    return parser.parse_args()


def read_version(root: Path) -> str:
    version_path = root / "VERSION"
    if not version_path.is_file():
        raise RuntimeError("VERSION is missing")

    version = version_path.read_text(encoding="utf-8-sig").strip()
    if not re.fullmatch(r"\d+(?:\.\d+){1,3}(?:[A-Za-z]|[-+][0-9A-Za-z.-]+)?", version):
        raise RuntimeError(f"invalid VERSION value: {version!r}")

    main = (root / "Main.ahk").read_text(encoding="utf-8-sig", errors="replace")
    match = VERSION_RE.search(main)
    if not match:
        raise RuntimeError('Main.ahk is missing the canonical ver := "..." assignment')
    if match.group(1) != version:
        raise RuntimeError(
            f"VERSION ({version}) does not match Main.ahk ({match.group(1)})"
        )
    return version


def forbidden(relative: Path) -> bool:
    normalized_parts = {part.casefold() for part in relative.parts}
    if normalized_parts & FORBIDDEN_PARTS:
        return True

    name = relative.name.casefold()
    if name in FORBIDDEN_NAMES:
        return True
    if relative.suffix.casefold() in FORBIDDEN_SUFFIXES:
        return True
    if name.startswith(".git"):
        return True
    return False


def collect_files(root: Path) -> list[Path]:
    selected: set[Path] = set()

    for relative in ROOT_FILES:
        path = root / relative
        if not path.is_file():
            raise RuntimeError(f"required release file is missing: {relative}")
        selected.add(Path(relative))

    for relative in OPTIONAL_ROOT_FILES:
        if (root / relative).is_file():
            selected.add(Path(relative))

    for runtime_root in RUNTIME_ROOTS:
        base = root / runtime_root
        if not base.exists():
            continue
        if not base.is_dir():
            raise RuntimeError(f"runtime root is not a directory: {runtime_root}")

        for path in base.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            if forbidden(relative):
                continue
            selected.add(relative)

    if not selected:
        raise RuntimeError("release selection is empty")

    return sorted(selected, key=lambda item: item.as_posix().casefold())


def write_zip(root: Path, output: Path, files: list[Path]) -> str:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    with zipfile.ZipFile(
        output,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
        allowZip64=True,
    ) as archive:
        for relative in files:
            data = (root / relative).read_bytes()
            info = zipfile.ZipInfo(relative.as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    return digest


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    output = Path(args.output)
    if not output.is_absolute():
        output = root / output

    try:
        version = read_version(root)
        files = collect_files(root)
        digest = write_zip(root, output, files)
    except (OSError, RuntimeError, zipfile.BadZipFile) as exc:
        print(f"release build failed: {exc}", file=sys.stderr)
        return 1

    print(f"version={version}")
    print(f"files={len(files)}")
    print(f"output={output}")
    print(f"sha256={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
