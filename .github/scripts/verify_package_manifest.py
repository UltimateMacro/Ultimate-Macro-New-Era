"""Verify the exact shipped files; repository-only docs/CI/source are additional."""
import hashlib
import json
import re
from pathlib import Path, PurePosixPath

def verify(root):
    root = Path(root).resolve()
    manifest = json.loads((root / "PACKAGE-MANIFEST.json").read_text(encoding="utf-8"))
    launcher = (root / "Main.ahk").read_text(encoding="utf-8-sig")
    versions = {}
    for name, value in re.findall(r'^\s*static\s+(SHORT_VERSION|RELEASE|UPDATE_VERSION)\s*:=\s*"([^"\n]+)"\s*$', launcher, re.MULTILINE):
        assert name not in versions, f"Duplicate launcher version: {name}"
        versions[name] = value
    assert set(versions) == {"SHORT_VERSION", "RELEASE", "UPDATE_VERSION"}, "Missing launcher version"
    assert re.fullmatch(r"1\.4\.\d+(?:\.\d+)?", versions["RELEASE"]), "Invalid release version"
    assert re.fullmatch(r"1\.4\.\d+\.\d+", versions["UPDATE_VERSION"]), "Invalid updater version"
    assert versions["SHORT_VERSION"] == versions["RELEASE"], "Launcher versions differ"
    assert manifest["version"] == versions["RELEASE"], "Manifest/launcher release mismatch"
    assert manifest["updateVersion"] == versions["UPDATE_VERSION"], "Manifest/launcher updater mismatch"
    seen = set()
    for item in manifest["files"]:
        relative = PurePosixPath(item["path"])
        assert not relative.is_absolute() and ".." not in relative.parts and "\\" not in item["path"]
        assert str(relative).casefold() not in seen
        seen.add(str(relative).casefold())
        file = root.joinpath(*relative.parts)
        assert file.is_file() and not file.is_symlink()
        assert file.resolve().is_relative_to(root)
        data = file.read_bytes()
        assert len(data) == item["bytes"], f"Wrong size: {relative}"
        assert hashlib.sha256(data).hexdigest() == item["sha256"], f"Wrong hash: {relative}"
        assert file.suffix.lower() not in {".dpapi", ".pfx", ".p12", ".key"}
        if file.suffix.lower() == ".pem":
            assert b"PRIVATE KEY" not in data
    assert "main.ahk" in seen, "Launcher missing from file manifest"
    return len(seen), manifest["version"], manifest["updateVersion"]


if __name__ == "__main__":
    count, release, update = verify(Path(__file__).resolve().parents[2])
    print(f"PASS: {count} shipped files match release {release}, updater {update}")
