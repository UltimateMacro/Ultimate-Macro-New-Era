from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from pathlib import Path

ROOT_FILES = (
    "Main.ahk",
    "README.md",
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
    "tower-catalog-status.csv",
}

COMMENT_STRIP_SUFFIXES = {
    ".ahk",
    ".js",
    ".ps1",
}

COMMENT_STRIP_EXEMPT_FILES = {
    "lib/Gdip_All.ahk",
    "lib/Gdip_ImageSearch.ahk",
    "lib/HyperSleep.ahk",
    "lib/ImageSearch/ImageSearch.ahk",
    "lib/JSON.ahk",
    "lib/OCR.ahk",
}

COMMENT_STRIP_EXEMPT_PREFIXES = (
    "_app/vendor/",
)

ESSENTIAL_COMMENT_MARKERS = (
    "copyright",
    "license",
    "licence",
    "original author",
    "original credit",
    "author:",
    "source:",
    "security:",
    "warning:",
    "important:",
    "do not remove",
    "must remain",
    "required by",
    "requires:",
    "@ahk2exe",
    "eslint-",
    "prettier-",
    "psscriptanalyzer",
    "sig # begin signature block",
    "sig # end signature block",
)

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


def is_comment_strip_target(relative: Path) -> bool:
    normalized = relative.as_posix()
    normalized_folded = normalized.casefold()

    if relative.suffix.casefold() not in COMMENT_STRIP_SUFFIXES:
        return False
    if normalized_folded in {path.casefold() for path in COMMENT_STRIP_EXEMPT_FILES}:
        return False
    return not any(
        normalized_folded.startswith(prefix.casefold())
        for prefix in COMMENT_STRIP_EXEMPT_PREFIXES
    )


def _is_essential_comment(text: str) -> bool:
    folded = text.casefold()
    return any(marker in folded for marker in ESSENTIAL_COMMENT_MARKERS)


def _leading_comment_block_end(lines: list[str], prefix: str) -> int:
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

    return end if saw_comment else 0


def _strip_ahk_line_comments(text: str) -> str:
    lines = text.splitlines(keepends=True)
    header_end = _leading_comment_block_end(lines, ";")
    output: list[str] = []

    for index, line in enumerate(lines):
        stripped = line.lstrip()
        if index < header_end:
            output.append(line)
            continue
        if stripped.startswith(";"):
            comment = stripped[1:].strip()
            if (
                stripped.startswith(";::")
                or stripped.startswith("; &")
                or _is_essential_comment(comment)
            ):
                output.append(line)
            continue
        output.append(line)

    return "".join(output)


def _strip_powershell_line_comments(text: str) -> str:
    lines = text.splitlines(keepends=True)
    header_end = _leading_comment_block_end(lines, "#")
    output: list[str] = []
    here_string_end = ""
    in_block_comment = False
    in_signature_block = False

    for index, line in enumerate(lines):
        stripped = line.lstrip()
        compact = stripped.strip()
        folded = compact.casefold()

        if in_signature_block:
            output.append(line)
            if "sig # end signature block" in folded:
                in_signature_block = False
            continue

        if "sig # begin signature block" in folded:
            in_signature_block = True
            output.append(line)
            continue

        if here_string_end:
            output.append(line)
            if compact == here_string_end:
                here_string_end = ""
            continue

        if in_block_comment:
            output.append(line)
            if "#>" in compact:
                in_block_comment = False
            continue

        if compact.startswith("<#"):
            in_block_comment = "#>" not in compact[2:]
            output.append(line)
            continue

        if re.search(r'@["\']\s*$', line):
            here_string_end = '"@' if line.rstrip().endswith('@"') else "'@"
            output.append(line)
            continue

        if index < header_end:
            output.append(line)
            continue

        if stripped.casefold().startswith("#requires"):
            output.append(line)
            continue

        if stripped.startswith("#"):
            comment = stripped[1:].strip()
            if _is_essential_comment(comment):
                output.append(line)
            continue

        output.append(line)

    return "".join(output)


def _toggle_js_template_state(line: str, in_template: bool) -> bool:
    escaped = False
    index = 0
    while index < len(line):
        char = line[index]
        if escaped:
            escaped = False
            index += 1
            continue
        if char == "\\":
            escaped = True
            index += 1
            continue
        if char == "`":
            in_template = not in_template
        index += 1
    return in_template


def _strip_js_line_comments(text: str) -> str:
    lines = text.splitlines(keepends=True)
    header_end = _leading_comment_block_end(lines, "//")
    output: list[str] = []
    in_template = False
    in_block_comment = False

    for index, line in enumerate(lines):
        stripped = line.lstrip()
        compact = stripped.strip()

        if in_block_comment:
            output.append(line)
            if "*/" in compact:
                in_block_comment = False
            continue

        if in_template:
            output.append(line)
            in_template = _toggle_js_template_state(line, in_template)
            continue

        if compact.startswith("/*"):
            in_block_comment = "*/" not in compact[2:]
            output.append(line)
            continue

        if index < header_end:
            output.append(line)
            in_template = _toggle_js_template_state(line, in_template)
            continue

        if stripped.startswith("//"):
            comment = stripped[2:].strip()
            if _is_essential_comment(comment):
                output.append(line)
            continue

        output.append(line)
        in_template = _toggle_js_template_state(line, in_template)

    return "".join(output)


def strip_release_comments(relative: Path, data: bytes) -> bytes:
    if not is_comment_strip_target(relative):
        return data

    had_bom = data.startswith(b"\xef\xbb\xbf")
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return data

    suffix = relative.suffix.casefold()
    if suffix == ".ahk":
        cleaned = _strip_ahk_line_comments(text)
    elif suffix == ".ps1":
        cleaned = _strip_powershell_line_comments(text)
    elif suffix == ".js":
        cleaned = _strip_js_line_comments(text)
    else:
        return data

    encoded = cleaned.encode("utf-8")
    if had_bom:
        encoded = b"\xef\xbb\xbf" + encoded
    return encoded


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
            data = strip_release_comments(relative, data)
            info = zipfile.ZipInfo(relative.as_posix(), date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(
                info,
                data,
                compress_type=zipfile.ZIP_DEFLATED,
                compresslevel=9,
            )

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
