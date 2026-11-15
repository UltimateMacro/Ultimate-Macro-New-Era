import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from verify_package_manifest import verify


class PackageChecks(unittest.TestCase):
    def make_package(self, root, release="1.4.1.4", update="1.4.1.4"):
        main = f'class App {{\n    static SHORT_VERSION := "{release}"\n    static RELEASE := "{release}"\n    static UPDATE_VERSION := "{update}"\n}}\n'
        (root / "Main.ahk").write_text(main, encoding="utf-8")
        data = (root / "Main.ahk").read_bytes()
        manifest = {"version": release, "updateVersion": update, "files": [{"path": "Main.ahk", "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}]}
        self.save(root, manifest)
        return manifest

    def save(self, root, manifest):
        (root / "PACKAGE-MANIFEST.json").write_text(json.dumps(manifest), encoding="utf-8")

    def test_current_and_future_versions_are_read_from_launcher(self):
        for release, update in [("1.4.1", "1.4.1.2"), ("1.4.1.4", "1.4.1.4"), ("1.4.2", "1.4.2.0")]:
            with self.subTest(release=release), tempfile.TemporaryDirectory(prefix="um-manifest-qa-") as temp:
                root = Path(temp)
                self.make_package(root, release, update)
                self.assertEqual(verify(root), (1, release, update))

    def test_release_and_updater_mismatches_still_fail(self):
        for field in ["version", "updateVersion"]:
            with self.subTest(field=field), tempfile.TemporaryDirectory(prefix="um-manifest-qa-") as temp:
                root = Path(temp)
                manifest = self.make_package(root)
                manifest[field] = "1.4.1.2"
                self.save(root, manifest)
                with self.assertRaises(AssertionError):
                    verify(root)

    def test_changed_hash_duplicate_path_and_missing_launcher_still_fail(self):
        for problem in ["hash", "duplicate", "missing"]:
            with self.subTest(problem=problem), tempfile.TemporaryDirectory(prefix="um-manifest-qa-") as temp:
                root = Path(temp)
                manifest = self.make_package(root)
                if problem == "hash":
                    manifest["files"][0]["sha256"] = "0" * 64
                elif problem == "duplicate":
                    manifest["files"].append(dict(manifest["files"][0]))
                else:
                    manifest["files"] = []
                self.save(root, manifest)
                with self.assertRaises(AssertionError):
                    verify(root)


if __name__ == "__main__":
    unittest.main()
