"""Verify the exact shipped files; repository-only docs/CI/source are additional."""
import hashlib
import json
from pathlib import Path, PurePosixPath

root = Path(__file__).resolve().parents[2]
manifest = json.loads((root / "PACKAGE-MANIFEST.json").read_text(encoding="utf-8"))
assert manifest["version"] == "1.4.1"
assert manifest["updateVersion"] == "1.4.1.2"
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
print(f"PASS: {len(seen)} shipped files match the tested 1.4.1.2 package")
