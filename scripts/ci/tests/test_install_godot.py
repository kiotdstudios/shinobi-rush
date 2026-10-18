import hashlib
import io
import json
import re
import shutil
import tempfile
import unittest
import zipfile
from unittest import mock
from pathlib import Path

from helpers import CI_DIR

import install_godot as ig
import pins

VERSION = "4.7.2"


def make_release(mirror: Path, platform: str) -> dict:
    """Write tiny fake release assets into mirror and return pin overrides computed from them."""
    names = ig.asset_names(VERSION, platform)
    zpath = mirror / str(names["zip"])
    with zipfile.ZipFile(zpath, "w") as z:
        for member in names["members"]:
            z.writestr(member, b"#!/bin/sh\necho fake godot\n")
    inner = io.BytesIO()
    with zipfile.ZipFile(inner, "w") as z:
        z.writestr("godot.html", "<html>")
    tpz = mirror / f"Godot_v{VERSION}-stable_export_templates.tpz"
    with zipfile.ZipFile(tpz, "w") as z:
        z.writestr("templates/version.txt", f"{VERSION}.stable\n")
        z.writestr("templates/web_nothreads_debug.zip", inner.getvalue())
        z.writestr("templates/web_debug.zip", inner.getvalue())
        z.writestr("templates/windows_debug_x86_64.exe", b"not extracted")
    sha = lambda p: hashlib.sha512(p.read_bytes()).hexdigest()  # noqa: E731
    return {str(names["pin"]): sha(zpath), "GODOT_EXPORT_TEMPLATES_SHA512": sha(tpz)}


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="ig-"))
        self.mirror = self.tmp / "mirror"
        self.mirror.mkdir()
        self.pins = pins.parse((CI_DIR / "godot-version.env").read_text(encoding="utf-8"))
        self.pins.update(make_release(self.mirror, "linux"))
        self.dest = self.tmp / "godot"

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def install(self, threaded=False):
        return ig.install(self.dest, "linux", self.pins, threaded, self.mirror.as_uri(), True)

    def test_installs_only_the_needed_files_and_writes_a_manifest(self):
        out = self.install()
        tpl = self.dest / "editor_data" / "export_templates" / f"{VERSION}.stable"
        self.assertEqual(sorted(p.name for p in tpl.iterdir()), ["version.txt", "web_nothreads_debug.zip"])
        self.assertTrue((self.dest / "_sc_").is_file())
        self.assertFalse((self.dest / ".download").exists())
        self.assertTrue(Path(out["GODOT_BIN"]).is_file())
        manifest = json.loads((self.dest / ig.MANIFEST).read_text(encoding="utf-8"))
        self.assertFalse(manifest["threaded_templates"])
        self.assertIn("editor_data/export_templates/4.7.2.stable/version.txt", manifest["files"])

    def test_threaded_templates_only_on_request(self):
        self.install(threaded=True)
        tpl = self.dest / "editor_data" / "export_templates" / f"{VERSION}.stable"
        self.assertIn("web_debug.zip", [p.name for p in tpl.iterdir()])
        self.assertEqual(ig.verify_install(self.dest, "linux", self.pins, threaded=False)[0][:8], "manifest")

    def test_second_install_is_a_verified_cache_hit(self):
        self.install()
        self.assertEqual(ig.verify_install(self.dest, "linux", self.pins, False), [])
        marker = self.dest / "marker.txt"
        marker.write_text("kept")
        self.install()
        self.assertTrue(marker.exists(), "a verified install must not be wiped")

    def test_tampered_file_is_detected_and_repaired(self):
        self.install()
        victim = self.dest / "editor_data" / "export_templates" / f"{VERSION}.stable" / "web_nothreads_debug.zip"
        victim.write_bytes(b"tampered")
        self.assertTrue(any("modified" in p for p in ig.verify_install(self.dest, "linux", self.pins, False)))
        self.install()
        self.assertEqual(ig.verify_install(self.dest, "linux", self.pins, False), [])

    def test_wrong_pin_fails_hard_and_leaves_no_download(self):
        self.pins["GODOT_EDITOR_LINUX_X86_64_SHA512"] = "0" * 128
        with self.assertRaisesRegex(ig.InstallError, "SHA512 mismatch"):
            self.install()
        self.assertFalse(list(self.dest.rglob("*.zip")))

    def test_refuses_to_wipe_a_foreign_directory(self):
        self.dest.mkdir()
        (self.dest / "precious.txt").write_text("keep")
        with self.assertRaisesRegex(ig.InstallError, "refusing to wipe"):
            self.install()
        self.assertTrue((self.dest / "precious.txt").exists())

    def test_missing_archive_member_is_an_error(self):
        names = ig.asset_names(VERSION, "linux")
        with zipfile.ZipFile(self.mirror / str(names["zip"]), "w") as z:
            z.writestr("something_else", b"x")
        self.pins[str(names["pin"])] = hashlib.sha512((self.mirror / str(names["zip"])).read_bytes()).hexdigest()
        with self.assertRaisesRegex(ig.InstallError, "does not contain the expected member"):
            self.install()

    def test_missing_asset_is_an_install_error_after_bounded_retries(self):
        (self.mirror / f"Godot_v{VERSION}-stable_linux.x86_64.zip").unlink()
        with mock.patch("install_godot.time.sleep") as sleep, self.assertRaisesRegex(ig.InstallError, "could not download"):
            self.install()
        self.assertEqual(sleep.call_count, 2)  # 3 attempts => 2 waits


if __name__ == "__main__":
    unittest.main()
