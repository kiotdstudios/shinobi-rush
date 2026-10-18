import argparse
import io
import json
import os
import re
import shutil
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

from helpers import GODOT_CLEAN_IMPORT, GODOT_MISSING_TEMPLATES, GODOT_PARSE_ERROR_IMPORT

import ci_common
import export_tools as et
import godot_ci
import godot_walker
import pages_gate as pg

SHA = "0123456789abcdef0123456789abcdef01234567"


def fake_export(d: Path) -> Path:
    """A structurally valid export (synthetic bytes with the real magic numbers)."""
    d.mkdir(parents=True)
    wasm = b"\x00asm" + b"\x01\x00\x00\x00" + b"x" * 1_100_000
    pck = b"GDPC" + b"\x00" * 200
    cfg = json.dumps({"executable": "index", "fileSizes": {"index.pck": len(pck), "index.wasm": len(wasm)}})
    (d / "index.wasm").write_bytes(wasm)
    (d / "index.pck").write_bytes(pck)
    (d / "index.js").write_bytes(b"//js\n" * 5000)
    (d / "index.html").write_text(f"<html>{'x' * 600}\nconst GODOT_CONFIG = {cfg};\nconst GODOT_THREADS_ENABLED = false;\n</html>", encoding="utf-8")
    return d


class ExportToolsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.d = fake_export(self.tmp / "web")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def errors(self, findings):
        return sorted({f.code for f in findings if f.level == "error"})

    def write_info(self, kind="game"):
        et.write_build_info(self.d, kind=kind, env={"GITHUB_SHA": SHA, "GITHUB_EVENT_NAME": "push"}, godot_version="4.7.2",
                            godot_version_string="4.7.2.stable.official.deadbeef0", project_dir=".", project_name="x")

    def test_valid_export_and_build_info(self):
        self.assertEqual(self.errors(et.check_export_dir(self.d)), [])
        self.write_info()
        self.assertEqual(et.check_build_info(self.d, kind="game", expect_sha=SHA), [])

    def test_structural_errors(self):
        (self.d / "index.wasm").write_bytes(b"nope" * 400_000)
        self.assertIn("EXPORT003", self.errors(et.check_export_dir(self.d)))
        (self.d / "index.pck").unlink()
        self.assertIn("EXPORT001", self.errors(et.check_export_dir(self.d)))

    def test_threaded_export_is_rejected(self):
        html = (self.d / "index.html").read_text(encoding="utf-8").replace("GODOT_THREADS_ENABLED = false", "GODOT_THREADS_ENABLED = true")
        (self.d / "index.html").write_text(html, encoding="utf-8")
        findings = et.check_export_dir(self.d)
        self.assertIn("EXPORT005", self.errors(findings))
        self.assertTrue(any("THREADED export" in f.message for f in findings))

    def test_file_sizes_in_godot_config_must_match(self):
        (self.d / "index.pck").write_bytes(b"GDPC" + b"\x00" * 50)
        self.assertIn("EXPORT006", self.errors(et.check_export_dir(self.d)))

    def test_selftest_export_is_refused_as_game_and_tampering_is_detected(self):
        self.write_info(kind="selftest")
        self.assertTrue(any("must never be deployed" in f.message for f in et.check_build_info(self.d, kind="game")))
        self.assertTrue(any("not the commit under test" in f.message for f in et.check_build_info(self.d, kind="selftest", expect_sha="f" * 40)))
        (self.d / "index.js").write_bytes(b"//tampered\n" * 5000)
        self.assertTrue(any("differs from the hash" in f.message for f in et.check_build_info(self.d, kind="selftest")))

    def test_build_info_needs_a_real_commit_sha(self):
        with self.assertRaises(ValueError):
            et.make_build_info(self.d, kind="game", env={"GITHUB_SHA": "abc"}, godot_version="4.7.2", godot_version_string="x", project_dir=".", project_name="x")


class PagesGateTests(unittest.TestCase):
    @staticmethod
    def needs(detect="success", found="true", build="success", pre="success", deploy="success", post="success"):
        return {
            "detect": {"result": detect, "outputs": {"project_found": found}},
            "build": {"result": build}, "smoke-predeploy": {"result": pre},
            "deploy": {"result": deploy}, "smoke-postdeploy": {"result": post},
        }

    def test_no_project_is_green_but_loud_and_requires_everything_skipped(self):
        g = pg.evaluate_gate(self.needs(found="false", build="skipped", pre="skipped", deploy="skipped", post="skipped"), "push", "refs/heads/main")
        self.assertTrue(g.ok)
        self.assertIn("NOT VALIDATED", g.headline)
        self.assertIn("NOT DEPLOYED", g.headline)
        self.assertIn("NOT evidence", pg.render_summary(g))
        self.assertFalse(pg.evaluate_gate(self.needs(found="false", build="success", pre="skipped", deploy="skipped", post="skipped"), "push", "refs/heads/main").ok)

    def test_every_violation_has_a_FAILED_headline_never_a_misleading_success_headline(self):
        S = "skipped"
        bad = [
            (self.needs(found="false", build="success", pre=S, deploy=S, post=S), "push", "refs/heads/main"),  # a Godot job ran with no project
            (self.needs(deploy=S, post=S), "push", "refs/heads/main"),  # a project, but the job that was skipped must have run
            (self.needs(build="failure", pre=S, deploy=S, post=S), "pull_request", "refs/pull/1/merge"),
            (self.needs(), "pull_request", "refs/pull/1/merge"),  # deploy ran on a PR
            (self.needs(detect="failure", found=""), "push", "refs/heads/main"),
            (self.needs(found=""), "push", "refs/heads/main"),
        ]
        for needs, event, ref in bad:
            with self.subTest(needs=needs):
                g = pg.evaluate_gate(needs, event, ref)
                self.assertFalse(g.ok)
                self.assertTrue(g.headline.startswith("FAILED:"), g.headline)
                self.assertNotIn("NOT VALIDATED", g.headline)
                self.assertNotIn("VALIDATED and DEPLOYED", g.headline)

    def test_detect_failure_fails(self):
        self.assertFalse(pg.evaluate_gate(self.needs(detect="failure", found=""), "push", "refs/heads/main").ok)

    def test_pull_request_with_project_never_deploys(self):
        S = "skipped"
        self.assertTrue(pg.evaluate_gate(self.needs(deploy=S, post=S), "pull_request", "refs/pull/1/merge").ok)
        self.assertFalse(pg.evaluate_gate(self.needs(build="failure", pre=S, deploy=S, post=S), "pull_request", "refs/pull/1/merge").ok)
        self.assertFalse(pg.evaluate_gate(self.needs(), "pull_request", "refs/pull/1/merge").ok, "a deploy on a PR is a bug")

    def test_main_with_project_requires_deploy_and_live_smoke(self):
        S = "skipped"
        self.assertTrue(pg.evaluate_gate(self.needs(), "push", "refs/heads/main").ok)
        self.assertFalse(pg.evaluate_gate(self.needs(deploy=S, post=S), "push", "refs/heads/main").ok, "skipped deploy on main is NOT success")
        self.assertFalse(pg.evaluate_gate(self.needs(post="failure"), "workflow_dispatch", "refs/heads/main").ok)
        self.assertFalse(pg.evaluate_gate(self.needs(build="cancelled", pre=S, deploy=S, post=S), "push", "refs/heads/main").ok)
        self.assertTrue(pg.evaluate_gate(self.needs(deploy=S, post=S), "workflow_dispatch", "refs/heads/feature").ok)

    def test_pages_preflight(self):
        ok = json.dumps({"build_type": "workflow", "cname": None, "html_url": "https://x.github.io/y/"})
        self.assertTrue(pg.evaluate_pages(0, ok, "", False).ok)
        res = pg.evaluate_pages(1, "", "gh: Not Found (HTTP 404)", False)
        self.assertFalse(res.ok)
        self.assertIn("NOT enabled", res.message)
        self.assertFalse(pg.evaluate_pages(1, "", "gh: Resource not accessible (HTTP 403)", False).ok)
        self.assertFalse(pg.evaluate_pages(0, json.dumps({"build_type": "legacy"}), "", False).ok)
        custom = json.dumps({"build_type": "workflow", "cname": "play.example.com"})
        self.assertFalse(pg.evaluate_pages(0, custom, "", False).ok)
        self.assertTrue(pg.evaluate_pages(0, custom, "", True).ok)
        self.assertFalse(pg.evaluate_pages(0, "<html>", "", False).ok)


class GodotCiTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.project = self.tmp / "proj"
        self.project.mkdir()
        (self.project / "project.godot").write_text("config_version=5\n")
        self.args = argparse.Namespace(project=str(self.project), godot=str(self.tmp / "godot"), log_dir=str(self.tmp / "logs"), out=str(self.tmp / "out"))
        (self.tmp / "godot").write_text("fake")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_step(self, returncode, text, timed_out=False, **kw):
        res = ci_common.RunResult(returncode, text, timed_out, 0.1)
        with mock.patch("godot_ci.run_logged", return_value=res), redirect_stdout(io.StringIO()):
            try:
                godot_ci.run_godot_step("import", self.args, ["--headless"], 5, **kw)
            except SystemExit as e:
                return e.code
        return 0

    def test_clean_run_passes(self):
        self.assertEqual(self.run_step(0, GODOT_CLEAN_IMPORT), 0)

    def test_exit_zero_with_engine_errors_fails(self):
        self.assertEqual(self.run_step(0, GODOT_PARSE_ERROR_IMPORT), 1)
        self.assertEqual(self.run_step(0, GODOT_MISSING_TEMPLATES), 1)

    def test_nonzero_exit_and_timeout_fail(self):
        self.assertEqual(self.run_step(1, GODOT_CLEAN_IMPORT), 1)
        self.assertEqual(self.run_step(-1, GODOT_CLEAN_IMPORT, timed_out=True), 1)

    def test_extra_error_pattern_fails_the_step(self):
        text = GODOT_CLEAN_IMPORT + "VALIDATE_RESOURCES_FAIL: script cannot be instantiated: res://broken.gd\n"
        self.assertEqual(self.run_step(0, text, extra_error_re=re.compile(r"^VALIDATE_RESOURCES_FAIL: ")), 1)

    def test_test_framework_detection_and_commands(self):
        self.assertEqual(godot_ci.detect_test_frameworks(self.project), [])
        (self.project / "addons" / "gut").mkdir(parents=True)
        (self.project / "addons" / "gut" / "gut_cmdln.gd").write_text("x")
        (self.project / "tests").mkdir()
        self.assertEqual(godot_ci.detect_test_frameworks(self.project), ["gut"])
        cmd = godot_ci.test_command("gut", self.project)
        self.assertIn("-gdir=res://tests", cmd)
        self.assertIn("-gexit", cmd)
        (self.project / ".gutconfig.json").write_text("{}")
        self.assertNotIn("-gdir=res://tests", godot_ci.test_command("gut", self.project))
        (self.project / "addons" / "gdUnit4" / "bin").mkdir(parents=True)
        (self.project / "addons" / "gdUnit4" / "bin" / "GdUnitCmdTool.gd").write_text("x")
        self.assertEqual(godot_ci.detect_test_frameworks(self.project), ["gut", "gdunit4"])
        self.assertIn("--ignoreHeadlessMode", godot_ci.test_command("gdunit4", self.project))

    def test_builtin_runner_is_detected_and_run_headless_with_the_script(self):
        (self.project / "tests").mkdir()
        self.assertEqual(godot_ci.detect_test_frameworks(self.project), [])
        (self.project / "tests" / "run_tests.gd").write_text("extends SceneTree\n")
        self.assertEqual(godot_ci.detect_test_frameworks(self.project), ["builtin"])
        self.assertEqual(godot_ci.test_command("builtin", self.project),
                         ["--headless", "--path", str(self.project), "--script", "res://tests/run_tests.gd"])
        (self.project / "addons" / "gut").mkdir(parents=True)
        (self.project / "addons" / "gut" / "gut_cmdln.gd").write_text("x")
        self.assertEqual(godot_ci.detect_test_frameworks(self.project), ["gut", "builtin"])

    def test_framework_without_a_tests_directory_runs_nothing_and_only_warns(self):
        (self.project / "addons" / "gut").mkdir(parents=True)
        (self.project / "addons" / "gut" / "gut_cmdln.gd").write_text("x")
        self.assertIsNone(godot_ci.test_command("gut", self.project))
        with mock.patch("godot_ci.run_godot_step") as step, redirect_stdout(io.StringIO()) as out:
            rc = godot_ci.cmd_tests(self.args)
        self.assertEqual(rc, 0)
        step.assert_not_called()
        self.assertIn("no tests ran", out.getvalue())

    def test_export_refuses_output_inside_the_project_or_non_empty(self):
        self.args.out = str(self.project / "build")
        with redirect_stdout(io.StringIO()):
            self.assertEqual(godot_ci.cmd_export(self.args), 1)
            self.args.out = str(self.tmp / "occupied")
            (self.tmp / "occupied").mkdir()
            (self.tmp / "occupied" / "x").write_text("x")
            self.assertEqual(godot_ci.cmd_export(self.args), 1)

    def test_export_of_a_repository_root_project_writes_outside_the_tree_only(self):
        """The repo-root convention: `--project .` is the checkout itself, and the preset's own default exports/web/ is inside res://.
        CI exports to a directory outside the project (RUNNER_TEMP); anything inside, or the project itself, is refused."""
        old = os.getcwd()
        os.chdir(self.project)
        try:
            self.args.project = "."
            for inside in ("exports/web", "web-export", ".", str(self.project), str(self.project / "exports" / "web")):
                with self.subTest(out=inside), redirect_stdout(io.StringIO()) as out:
                    self.args.out = inside
                    self.assertEqual(godot_ci.cmd_export(self.args), 1)
                    self.assertIn("inside the project directory", out.getvalue())
            outside = self.tmp / "runner-temp" / "web-export"
            self.args.out = str(outside)
            with mock.patch("godot_ci.run_logged", return_value=ci_common.RunResult(0, "[ DONE ] reimport\n", False, 0.1)), redirect_stdout(io.StringIO()):
                godot_ci.cmd_export(self.args)
            self.assertTrue(outside.is_dir())
            self.assertEqual(sorted(p.name for p in self.project.iterdir()), ["project.godot"], "nothing was written into the project tree")
        finally:
            os.chdir(old)

    @staticmethod
    def fake_walker_run(log_text, seen):
        """Stands in for run_logged: records the script Godot was told to run, writes the log file the way run_logged does."""
        def run(cmd, log_path=None, timeout=None, **kw):
            script = Path(cmd[cmd.index("--script") + 1])
            seen.update(script=script, existed=script.is_file(), content=script.read_bytes() if script.is_file() else b"", cmd=list(cmd))
            Path(log_path).parent.mkdir(parents=True, exist_ok=True)
            Path(log_path).write_text(log_text, encoding="utf-8")
            return ci_common.RunResult(0, log_text, False, 0.1)
        return run

    def test_validate_resources_runs_the_walker_from_outside_the_project_and_removes_it(self):
        log = "[ DONE ]\nVALIDATE_RESOURCES: scripts=3 scenes=1 resources=0 failures=0\nVALIDATE_RESOURCES_SKIPPED: res://.godot, res://docs, res://scripts/ci\n"
        seen = {}
        with mock.patch("godot_ci.run_logged", side_effect=self.fake_walker_run(log, seen)), redirect_stdout(io.StringIO()) as out:
            rc = godot_ci.cmd_validate_resources(self.args)
        self.assertEqual(rc, 0)
        script = seen["script"]
        self.assertTrue(seen["existed"])
        self.assertEqual(seen["content"], godot_walker.walker_source().encode("utf-8"))
        self.assertNotIn(self.project.resolve(), script.resolve().parents, "the walker is never written into res://")
        self.assertFalse(script.exists(), "the temporary folder is removed afterwards")
        self.assertEqual(seen["cmd"][seen["cmd"].index("--path") + 1], str(self.project.resolve()))
        self.assertIn("validated 3 scripts, 1 scenes, 0 resources, 0 failures", out.getvalue())
        self.assertIn("not walked: res://.godot, res://docs, res://scripts/ci", out.getvalue())
        self.assertEqual(sorted(p.name for p in self.project.iterdir()), ["project.godot"])

    def test_validate_resources_fails_on_a_failure_line_and_on_a_missing_summary(self):
        bad = "VALIDATE_RESOURCES: scripts=1 scenes=0 resources=0 failures=1\nVALIDATE_RESOURCES_FAIL: script failed to load/compile: res://broken.gd\n"
        with mock.patch("godot_ci.run_logged", side_effect=self.fake_walker_run(bad, {})), redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as cm:
                godot_ci.cmd_validate_resources(self.args)
        self.assertEqual(cm.exception.code, 1)
        with mock.patch("godot_ci.run_logged", side_effect=self.fake_walker_run("[ DONE ]\n", {})), redirect_stdout(io.StringIO()):
            self.assertEqual(godot_ci.cmd_validate_resources(self.args), 1, "Godot exited 0 without printing the summary line")

    def test_validate_resources_refuses_a_temporary_directory_inside_the_project(self):
        with mock.patch.object(tempfile, "tempdir", str(self.project)), mock.patch("godot_ci.run_logged") as run, redirect_stdout(io.StringIO()):
            with self.assertRaises(ValueError):
                godot_ci.cmd_validate_resources(self.args)
        run.assert_not_called()
        self.assertEqual(sorted(p.name for p in self.project.iterdir()), ["project.godot"], "the temporary folder is removed again")


if __name__ == "__main__":
    unittest.main()
