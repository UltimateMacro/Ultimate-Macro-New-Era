"""Check that the macro package is complete: every file the scripts load or launch exists.

1.3.3c ships straight from the repo (users download the release ZIP), so there is
no hash manifest. Instead this verifies, for Main.ahk, lib/ and submacros/:
  - every #Include target exists (case-sensitive match, so it also works on Linux),
  - every submacros\\<name> file that Main.ahk runs exists,
  - every literal Resources\\... file path in the code exists,
and that no key or certificate files are committed.
"""
import re
import sys
from pathlib import Path, PureWindowsPath

REQUIRED = ["Main.ahk", "icon.ico", "submacros/AutoHotkey64.exe", "submacros/AutoHotkey32.exe"]
FORBIDDEN_SUFFIXES = {".dpapi", ".pfx", ".p12", ".key"}
INCLUDE = re.compile(r'^\s*#Include(?:Again)?\s+(?:\*i\s+)?"?([^"\r\n;]+?)"?\s*(?:;.*)?$', re.IGNORECASE | re.MULTILINE)
SUBMACRO = re.compile(r'submacros\\([\w.\-]+\.(?:ahk|exe|bat))', re.IGNORECASE)
RESOURCE = re.compile(r'Resources\\[^"\'\r\n%*?<>|]+?\.(?:png|jpe?g|json|strat|wav|ico)\b', re.IGNORECASE)


def exact(root: Path, relative: str) -> bool:
    """True if the path exists with exactly this letter case (Windows is case-insensitive, CI isn't)."""
    current = root
    for part in PureWindowsPath(relative).parts:
        if part in ("", "."):
            continue
        if part == "..":
            current = current.parent
            continue
        if not current.is_dir() or part not in {p.name for p in current.iterdir()}:
            return False
        current = current / part
    return current.exists()


def resolve_include(script: Path, root: Path, target: str):
    """Return the include target relative to root, or None for library (<Name>) includes."""
    target = target.strip()
    if target.startswith("<"):
        return None
    if "%A_LineFile%" in target:
        base = script.parent
        target = target.replace("%A_LineFile%", "").lstrip("\\/")
        # A_LineFile is the file itself, so the first ".." means "this folder".
        parts = list(PureWindowsPath(target.replace("/", "\\")).parts)
        if parts and parts[0] == "..":
            parts = parts[1:]
        path = base.joinpath(*parts) if parts else base
    elif "%A_ScriptDir%" in target:
        path = script.parent.joinpath(*PureWindowsPath(target.replace("%A_ScriptDir%", "").lstrip("\\/")).parts)
    else:
        path = script.parent.joinpath(*PureWindowsPath(target).parts)
    path = Path(*[p for p in path.parts])
    try:
        resolved = Path(str(path)).resolve(strict=False)
        return resolved.relative_to(root.resolve()).as_posix()
    except ValueError:
        return f"<outside repo> {target}"


def scripts(root: Path):
    yield root / "Main.ahk"
    for folder in ("lib", "submacros"):
        yield from sorted((root / folder).rglob("*.ahk"))


def verify(root):
    root = Path(root).resolve()
    problems = []

    for item in REQUIRED:
        if not exact(root, item):
            problems.append(f"required file missing: {item}")

    checked = 0
    for script in scripts(root):
        if not script.is_file():
            continue
        rel = script.relative_to(root).as_posix()
        text = script.read_text(encoding="utf-8-sig", errors="replace")

        for target in INCLUDE.findall(text):
            if target.strip().lower().startswith("*i"):
                continue
            resolved = resolve_include(script, root, target)
            if resolved is None:
                continue
            checked += 1
            if resolved.startswith("<outside repo>") or not exact(root, resolved):
                problems.append(f"{rel}: #Include target missing: {target.strip()}")

        for name in sorted(set(SUBMACRO.findall(text))):
            checked += 1
            if not exact(root, f"submacros/{name}"):
                problems.append(f"{rel}: launches missing submacros\\{name}")

        for resource in sorted(set(RESOURCE.findall(text))):
            checked += 1
            if not exact(root, resource):
                problems.append(f"{rel}: references missing {resource}")

    for file in root.rglob("*"):
        if ".git" in file.relative_to(root).parts or not file.is_file():
            continue
        if file.suffix.lower() in FORBIDDEN_SUFFIXES:
            problems.append(f"key/certificate file must not be committed: {file.relative_to(root).as_posix()}")
        elif file.suffix.lower() == ".pem" and b"PRIVATE KEY" in file.read_bytes():
            problems.append(f"private key must not be committed: {file.relative_to(root).as_posix()}")

    assert not problems, "\n".join(problems)
    return checked


if __name__ == "__main__":
    try:
        count = verify(Path(__file__).resolve().parents[2])
    except AssertionError as exc:
        for line in str(exc).splitlines():
            print(f"::error::{line}")
        sys.exit(1)
    print(f"PASS: {count} include, submacro and resource references all resolve")
