from pathlib import Path
import tempfile
import unittest
from verify_package_manifest import verify


class PackageChecks(unittest.TestCase):
    def make_package(self, root: Path):
        (root / "lib").mkdir()
        (root / "submacros").mkdir()
        (root / "Resources").mkdir()
        (root / "icon.ico").write_bytes(b"ico")
        (root / "submacros" / "AutoHotkey64.exe").write_bytes(b"exe")
        (root / "submacros" / "AutoHotkey32.exe").write_bytes(b"exe")
        (root / "Resources" / "Ready.png").write_bytes(b"png")
        (root / "lib" / "JSON.ahk").write_text("JSONLoad() {\n}\n", encoding="utf-8")
        (root / "submacros" / "watchdog.ahk").write_text(
            '#Include "%A_LineFile%\\..\\..\\lib\\JSON.ahk"\n', encoding="utf-8")
        (root / "Main.ahk").write_text(
            "#Include lib\\JSON.ahk\n"
            "Run('\"' A_ScriptDir '\\submacros\\AutoHotkey64.exe\" \"' A_ScriptDir '\\submacros\\watchdog.ahk\"')\n"
            'ImageSearch(&x, &y, 0, 0, 100, 100, "Resources\\Ready.png")\n',
            encoding="utf-8")

    def broken(self, change):
        with tempfile.TemporaryDirectory(prefix="um-package-qa-") as temp:
            root = Path(temp)
            self.make_package(root)
            change(root)
            with self.assertRaises(AssertionError):
                verify(root)

    def test_complete_package_passes(self):
        with tempfile.TemporaryDirectory(prefix="um-package-qa-") as temp:
            root = Path(temp)
            self.make_package(root)
            self.assertGreater(verify(root), 0)

    def test_missing_include_fails(self):
        self.broken(lambda root: (root / "lib" / "JSON.ahk").unlink())

    def test_missing_submacro_fails(self):
        self.broken(lambda root: (root / "submacros" / "watchdog.ahk").unlink())

    def test_missing_resource_fails(self):
        self.broken(lambda root: (root / "Resources" / "Ready.png").unlink())

    def test_wrong_letter_case_fails(self):
        self.broken(lambda root: (root / "Resources" / "Ready.png").rename(root / "Resources" / "ready.png"))

    def test_missing_runtime_fails(self):
        self.broken(lambda root: (root / "submacros" / "AutoHotkey32.exe").unlink())

    def test_committed_key_fails(self):
        self.broken(lambda root: (root / "secret.key").write_bytes(b"k"))


if __name__ == "__main__":
    unittest.main()
