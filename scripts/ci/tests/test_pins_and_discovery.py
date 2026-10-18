import contextlib
import io
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from helpers import CI_DIR

import discover_project
import pins


class PinTests(unittest.TestCase):
    def setUp(self):
        self.text = (CI_DIR / "godot-version.env").read_text(encoding="utf-8")

    def test_real_pin_file_is_valid(self):
        p = pins.parse(self.text)
        self.assertEqual(len(p["GODOT_EDITOR_LINUX_X86_64_SHA512"]), 128)
        self.assertEqual(pins.derived(p)["GODOT_TAG"], f"{p['GODOT_VERSION']}-stable")
        self.assertRegex(pins.derived(p)["GODOT_CACHE_KEY"], r"^godot-\d+\.\d+(\.\d+)?-e[0-9a-f]{12}-t[0-9a-f]{12}-v\d+$")

    def test_rejects_malformed_pins(self):
        for extra in ('GODOT_VERSION="4.7.2"', "GODOT_VERSION = 4.7.2", "GODOT_EDITOR_WIN64_SHA512=abc", "RUNNER_IMAGE=ubuntu-latest", "SURPRISE=1"):
            with self.subTest(extra=extra), self.assertRaises(pins.PinError):
                pins.parse(self.text + "\n" + extra + "\n")

    def test_missing_key_is_reported(self):
        with self.assertRaisesRegex(pins.PinError, "missing key NODE_VERSION"):
            pins.parse(self.text.replace("NODE_VERSION=", "#NODE_VERSION="))

    def test_markdown_table_uses_checkable_markers(self):
        table = pins.markdown_table(pins.parse(self.text))
        self.assertRegex(table, r"<!--pin:GODOT_VERSION-->`[0-9.]+`<!--/pin-->")

    def test_bump_godot_rewrites_only_the_godot_values_and_validates(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            f = tmp / "godot-version.env"
            f.write_text(self.text, encoding="utf-8")
            sums = "\n".join(f"{c * 128}  {n}" for c, n in (("a", "Godot_v4.8.1-stable_linux.x86_64.zip"), ("b", "Godot_v4.8.1-stable_win64.exe.zip"), ("c", "Godot_v4.8.1-stable_export_templates.tpz")))
            new = pins.bump_godot(f, sums, "4.8.1")
            self.assertEqual(new["GODOT_EDITOR_WIN64_SHA512"], "b" * 128)
            reread = pins.parse(f.read_text(encoding="utf-8"))
            self.assertEqual(reread["GODOT_VERSION"], "4.8.1")
            self.assertEqual(reread["NODE_VERSION"], pins.parse(self.text)["NODE_VERSION"])
            with self.assertRaises(pins.PinError):
                pins.bump_godot(f, sums, "9.9.9")  # not in the sums file
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


class DiscoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def mk(self, rel):
        p = self.tmp / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("config_version=5\n")

    def test_no_project(self):
        self.assertEqual(discover_project.discover(self.tmp)[0], "none")

    def test_ignored_directories_never_count(self):
        for rel in (".git/x/project.godot", ".godot/project.godot", "node_modules/p/project.godot", ".import/project.godot"):
            self.mk(rel)
        self.assertEqual(discover_project.discover(self.tmp)[0], "none")

    def test_single_project_any_location_and_nested_projects_ignored(self):
        """Discovery is generic (nothing is hard-coded); the repository convention is the root, see the next tests."""
        self.mk("godot_project/project.godot")
        self.mk("godot_project/addons/demo/project.godot")
        status, project, _ = discover_project.discover(self.tmp)
        self.assertEqual((status, discover_project.posix(project)), ("one", "godot_project"))

    def test_project_at_repository_root(self):
        self.mk("project.godot")
        self.mk("sub/project.godot")
        status, project, _ = discover_project.discover(self.tmp)
        self.assertEqual((status, discover_project.posix(project)), ("one", "."))

    def test_project_at_repository_root_next_to_non_game_folders_full_of_images(self):
        """The convention (docs/prototype/PLAYER_CHARACTER_CODEX_HANDOFF.md section 11): project.godot at the repository root,
        sharing the tree with docs, orders, world, skills, scripts/ci and the approved turnaround. Discovery says '.'."""
        self.mk("project.godot")
        for rel in ("docs/visuals/hud/wireframe.svg", "world/maps/overview.png", "assets/characters/player/references/baseline_turnaround.png",
                    "assets/characters/player/placeholder/placeholder.png", "orders/Kiro/order_01.md", "skills/README.md"):
            p = self.tmp / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(b"not a godot file")
        for rel in ("docs/.gdignore", "scripts/ci/.gdignore"):
            (self.tmp / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.tmp / rel).write_bytes(b"")
        self.mk("scripts/ci/smoke/node_modules/pkg/project.godot")  # tooling dependencies never count
        self.mk(".agents/skills/sample/project.godot")  # nested below the root project: Godot ignores it, so does discovery
        status, project, candidates = discover_project.discover(self.tmp)
        self.assertEqual((status, discover_project.posix(project), [discover_project.posix(c) for c in candidates]), ("one", ".", ["."]))

    def test_the_override_may_name_the_repository_root(self):
        self.mk("project.godot")
        for value in (".", "./"):
            with self.subTest(value=value):
                self.assertEqual(discover_project.posix(discover_project.discover(self.tmp, value)[1]), ".")
        with self.assertRaisesRegex(ValueError, "repository root"):
            discover_project.discover(self.tmp, "/abs")  # the message names the convention

    def run_main(self, **env):
        out, outputs = io.StringIO(), self.tmp / "github_output.txt"
        full = {"GITHUB_WORKSPACE": str(self.tmp), "GITHUB_OUTPUT": str(outputs), "GITHUB_ACTIONS": "true", "GODOT_PROJECT_DIR": ""}
        full.update(env)
        with mock.patch.dict(os.environ, full), contextlib.redirect_stdout(out):
            rc = discover_project.main()
        return rc, out.getvalue(), dict(line.split("=", 1) for line in outputs.read_text(encoding="utf-8").splitlines()) if outputs.exists() else {}

    def test_main_reports_the_root_project_as_dot(self):
        self.mk("project.godot")
        rc, text, outputs = self.run_main()
        self.assertEqual((rc, outputs), (0, {"project_found": "true", "project_dir": ".", "export_presets_present": "false"}))
        self.assertIn("::notice", text)
        self.assertIn("export_presets.cfg missing", text, "a project without a Web preset is a loud warning, not a pass")
        (self.tmp / "export_presets.cfg").write_text("")
        self.assertEqual(self.run_main()[2]["export_presets_present"], "true")

    def test_main_without_a_project_is_loud_about_not_validated_and_not_deployed_and_names_stage_2(self):
        rc, text, outputs = self.run_main()
        self.assertEqual((rc, outputs["project_found"], outputs["project_dir"]), (0, "false", ""))
        self.assertIn("NOT VALIDATED", text)
        self.assertIn("NOT DEPLOYED", text)
        self.assertIn("stage 2 of Order 01", text)
        self.assertIn("repository root", text)

    def test_several_projects_are_ambiguous_without_override(self):
        self.mk("a/project.godot")
        self.mk("b/project.godot")
        status, _, candidates = discover_project.discover(self.tmp)
        self.assertEqual(status, "ambiguous")
        self.assertEqual([discover_project.posix(c) for c in candidates], ["a", "b"])

    def test_override_resolves_ambiguity_and_is_validated(self):
        self.mk("a/project.godot")
        self.mk("b/project.godot")
        self.assertEqual(discover_project.posix(discover_project.discover(self.tmp, "b")[1]), "b")
        for bad in ("missing", "../x", "/abs", "C:/abs", "a\\b", ""):
            if bad == "":
                continue
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                discover_project.discover(self.tmp, bad)


if __name__ == "__main__":
    unittest.main()
