from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path


REQUIRED_RUNTIME_FILES = (
    "Main.ahk",
    "lib/Gdip_All.ahk",
    "lib/Gdip_ImageSearch.ahk",
    "lib/HyperSleep.ahk",
    "lib/ImageSearch/ImageSearch.ahk",
    "lib/Discord.ahk",
    "lib/OCR.ahk",
    "lib/JSON.ahk",
    "lib/Roblox.ahk",
    "lib/RuntimeLog.ahk",
    "submacros/updater.ahk",
    "submacros/update.bat",
    "submacros/safe_update.ps1",
    "submacros/watchdog.ahk",
)

REQUIRED_QA_FILES = (
    ".github/workflows/ci.yml",
    ".github/pull_request_template.md",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/config.yml",
    "PLAN.md",
    "DEPENDENCIES.md",
    "SECURITY.md",
    "TESTING.md",
    "QA_CHECKLIST.md",
    "CONTRIBUTING.md",
    "docs/BRANCH_PROTECTION.md",
)

# These paths are assembled dynamically in the AHK source, so a literal-string
# scan cannot discover them. Every listed file is used by current runtime code.
DYNAMIC_RUNTIME_RESOURCES = (
    "Resources/Badlands II.png",
    "Resources/Casual.png",
    "Resources/Easy.png",
    "Resources/Fallen.png",
    "Resources/Frost.png",
    "Resources/Intermediate.png",
    "Resources/Molten.png",
    "Resources/Pizza Party.png",
    "Resources/Polluted Wasteland II.png",
    "Resources/Voidcore.png",
    "Resources/SpecialMode.png",
    "Resources/triumph.png",
    "Resources/YouLost.png",
)

APPROVED_BINARIES = {
    "lib/imagesearch/image_search.dll": (
        "346d25b9baf582b4cd5550fceaa57f4b1e18f10ae38007ba52ccd07bd790221e"
    ),
    "lib/imagesearch/msvcp140.dll": (
        "7c26614e1d733892c2deac7e245ce115504b1d80592dd0a01b08e3e5a55f89ca"
    ),
    "submacros/autohotkey32.exe": (
        "05fcaf6f09b9fe4b85887f75183310d34166a0b854ca0907b497808be7b8f87d"
    ),
    "submacros/autohotkey64.exe": (
        "37ff15a23a98f0a658298e21f1873ca896a05208810bf796f90ca212ee07c7b1"
    ),
}

GENERATED_OR_PRIVATE_PATHS = {
    "lib/ocr.ahk",
    "lib/json.ahk",
    "state.ini",
    "overall_stats.ini",
    "run_ledger.csv",
}

TEXT_EXTENSIONS = {
    ".ahk",
    ".bat",
    ".ini",
    ".json",
    ".md",
    ".ps1",
    ".py",
    ".strat",
    ".tds",
    ".txt",
    ".yaml",
    ".yml",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def tracked_files(root: Path) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        raise RuntimeError("git ls-files failed; repository validation needs a Git checkout")
    return sorted(item for item in result.stdout.decode("utf-8").split("\0") if item)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def validate_required_files(root: Path, errors: list[str]) -> None:
    for relative in REQUIRED_RUNTIME_FILES + REQUIRED_QA_FILES:
        if not (root / relative).is_file():
            fail(errors, f"required project file is missing: {relative}")


def validate_main_includes(root: Path, errors: list[str]) -> None:
    main = read_text(root / "Main.ahk")
    include_re = re.compile(r"(?im)^\s*#Include\s+(?:\*i\s+)?(.+?)\s*$")

    for raw in include_re.findall(main):
        raw = raw.strip().strip('"')
        if "%" in raw:
            continue
        relative = raw.replace("\\", "/")
        if not (root / relative).is_file():
            fail(errors, f"Main.ahk include is missing: {raw}")


def validate_resources(root: Path, errors: list[str]) -> None:
    resource_re = re.compile(
        r"Resources[\\/][^\"'\r\n]+?\.(?:png|gif|ico|jpg|jpeg|bmp)", re.I
    )
    references = set(DYNAMIC_RUNTIME_RESOURCES)

    for source in root.rglob("*.ahk"):
        for match in resource_re.findall(read_text(source)):
            normalized = match.lstrip("\\/").replace("\\", "/")
            normalized = re.sub(r"/+", "/", normalized)
            references.add(normalized)

    actual = {
        path.relative_to(root).as_posix().casefold()
        for path in (root / "Resources").rglob("*")
        if path.is_file()
    }

    for reference in sorted(references):
        if reference.casefold() not in actual:
            fail(errors, f"runtime resource is missing: {reference}")

def validate_binary_scope(root: Path, tracked: list[str], errors: list[str]) -> None:
    binaries = {
        relative.casefold(): relative
        for relative in tracked
        if Path(relative).suffix.casefold() in {".dll", ".exe"}
    }

    for normalized, relative in binaries.items():
        if normalized not in APPROVED_BINARIES:
            fail(errors, f"unapproved tracked binary: {relative}")
            continue

        actual = hashlib.sha256((root / relative).read_bytes()).hexdigest()
        if actual != APPROVED_BINARIES[normalized]:
            fail(errors, f"approved binary hash changed without review: {relative}")

    for required in APPROVED_BINARIES:
        if required not in binaries:
            fail(errors, f"expected upstream binary is missing: {required}")


def validate_tracked_scope(tracked: list[str], errors: list[str]) -> None:
    for relative in tracked:
        normalized = relative.replace("\\", "/").casefold()
        name = Path(normalized).name

        if normalized in GENERATED_OR_PRIVATE_PATHS:
            fail(errors, f"generated/private file must not be tracked: {relative}")
        if normalized.startswith(("options/", "recordings/")):
            fail(errors, f"runtime state directory must not be tracked: {relative}")
        if "strategy lab" in normalized or "strategy_lab" in normalized:
            fail(errors, f"experimental Strategy Lab file is out of scope: {relative}")
        if "remote 2.0" in normalized or "remote2.0" in normalized:
            fail(errors, f"Remote 2.0 file is out of scope: {relative}")
        if "screenshot" in name and Path(normalized).suffix in {".png", ".jpg", ".jpeg"}:
            fail(errors, f"accidental screenshot is tracked: {relative}")


def validate_text_hygiene(root: Path, tracked: list[str], errors: list[str]) -> None:
    secret_patterns = (
        (
            "Discord webhook URL",
            re.compile(
                r"https://(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/"
                r"\d{10,}/[A-Za-z0-9._-]{20,}",
                re.I,
            ),
        ),
        (
            "Discord bot token assignment",
            re.compile(r"(?i)bot[_ ]?token\s*(?::=|=)\s*[\"'][A-Za-z0-9._-]{30,}[\"']"),
        ),
        (
            "Roblox private-server code",
            re.compile(r"(?i)(?:privateServerLinkCode=|roblox\.com/share\?code=)[a-f0-9]{32}"),
        ),
    )

    for relative in tracked:
        path = root / relative
        if path.suffix.casefold() not in TEXT_EXTENSIONS:
            continue
        text = read_text(path)
        if re.search(r"(?m)^(?:<<<<<<<|>>>>>>>)", text):
            fail(errors, f"unresolved merge marker: {relative}")
        for label, pattern in secret_patterns:
            if pattern.search(text):
                fail(errors, f"possible {label} in tracked file: {relative}")


def validate_dependency_bootstrap(root: Path, errors: list[str]) -> None:
    source = read_text(root / "tools" / "sync_dependencies.ps1")
    markers = (
        "15154d1477eb21ade15dc82a62594053face757f",
        "8b143a4df95e4a447389434c4f75017235339a44",
        "ed348c0be111692c4ffeb9dcc8a9f524c575d48d7f81c8bcd96b882bb7375124",
        "4d1fe28493bcb665d7fcccce1289ed9a36df4ff0",
        "d384f62d611ffdbd16e4fcfb97fc32ec4e4e41d5",
        "1d215d4acb9c6ac6205c1f586cc0868b72c0d557a77890e89b83a1960c9498e2",
        "Assert-DependencyHash",
    )
    for marker in markers:
        if marker not in source:
            fail(errors, f"dependency bootstrap contract is missing: {marker}")


def validate_updater(root: Path, errors: list[str]) -> None:
    updater = read_text(root / "submacros" / "updater.ahk")
    safe = read_text(root / "submacros" / "safe_update.ps1")
    wrapper = read_text(root / "submacros" / "update.bat")

    updater_markers = (
        "https://api.github.com/repos/DarksenDev/tds-macro/releases/latest",
        r"https://github\.com/DarksenDev/tds-macro/releases/download/",
        'PreferredAsset := "TDS_Macro.zip"',
        "JSON.parse",
        'asset["digest"]',
        "CompareMacroVersions",
        "GetCurrentProcessId",
        "safe_update.ps1",
    )
    safe_markers = (
        "Assert-InstallRoot",
        "/DarksenDev/tds-macro/releases/download/",
        "Normalize-Sha256",
        "Assert-SafeZip",
        "Assert-RuntimePayload",
        "Assert-PayloadVersion",
        "Restore-PreservedStrategies",
        "Creating rollback backup",
        "The previous installation was restored",
    )
    for marker in updater_markers:
        if marker not in updater:
            fail(errors, f"updater contract is missing: {marker}")
    for marker in safe_markers:
        if marker not in safe:
            fail(errors, f"safe updater contract is missing: {marker}")

    if "UltimateMacro/Ultimate-Macro-New-Era/releases/latest" in updater:
        fail(errors, "updater still references the retired release repository")
    if "UltimateMacro/Ultimate-Macro-New-Era/releases/download" in updater:
        fail(errors, "updater still allows assets from the retired release repository")
    if "UltimateMacro/Ultimate-Macro-New-Era/releases/download" in safe:
        fail(errors, "safe updater still allows assets from the retired release repository")
    if "checksum verification was skipped" in safe.casefold():
        fail(errors, "safe updater permits installation without a checksum")
    for destructive in ("del /f /s /q", "rd /s /q", "Expand-Archive"):
        if destructive.casefold() in wrapper.casefold():
            fail(errors, f"batch wrapper contains legacy destructive behavior: {destructive}")
    if "safe_update.ps1" not in wrapper:
        fail(errors, "batch wrapper does not delegate to safe_update.ps1")


def validate_ci_workflow(root: Path, errors: list[str]) -> None:
    workflow = read_text(root / ".github" / "workflows" / "ci.yml")
    markers = (
        "permissions:\n  contents: read",
        "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1",
        "actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97",
        "./tools/sync_dependencies.ps1",
        "python tests/test_source_contracts.py .",
        "python tests/validate_repo.py .",
        "python tests/lint_strategies.py .",
        "./tools/validate_powershell.ps1",
        "./tests/safe_updater_smoke.ps1",
        "./tools/validate_ahk.ps1",
    )
    for marker in markers:
        if marker not in workflow:
            fail(errors, f"CI workflow contract is missing: {marker}")


def validate(root: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    tracked = tracked_files(root)

    validate_required_files(root, errors)
    if (root / "Main.ahk").is_file():
        validate_main_includes(root, errors)
    if (root / "Resources").is_dir():
        validate_resources(root, errors)
    validate_binary_scope(root, tracked, errors)
    validate_tracked_scope(tracked, errors)
    validate_text_hygiene(root, tracked, errors)
    validate_dependency_bootstrap(root, errors)
    validate_updater(root, errors)
    validate_ci_workflow(root, errors)

    if not (root / "lib" / "ImageSearch" / "opencv_world500.dll").is_file():
        warnings.append(
            "opencv_world500.dll is intentionally absent; runtime image search must use the GDI+ fallback"
        )

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    args = parser.parse_args()
    root = Path(args.root).resolve()

    errors, warnings = validate(root)
    for warning in warnings:
        print(f"WARN: {warning}")
    for error in errors:
        print(f"ERROR: {error}")

    if errors:
        print(f"repository validation: FAIL ({len(errors)} error(s))")
        return 1

    print("repository validation: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
