"""Safety rails (no destructive surprises), output-size handling, commit-id strictness and the self-test harness itself."""
import argparse
import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

from helpers import REPO_ROOT

import ci_common
import export_tools as et
import godot_ci
import godot_log
import selftest
import validate_godot_project as v
from test_export_gate_and_ci import SHA, fake_export


class RefuseUnsafeDeleteTests(unittest.TestCase):
    def test_roots_home_cwd_checkout_and_their_ancestors_are_refused(self):
        anchor = Path(Path.cwd().anchor)
        for p in (anchor, Path.home(), Path.cwd(), REPO_ROOT, REPO_ROOT.parent, Path.home().parent):
            with self.subTest(path=str(p)), self.assertRaises(ci_common.UnsafePath):
                ci_common.refuse_unsafe_delete(p)

    def test_an_ordinary_scratch_directory_is_allowed(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            self.assertEqual(ci_common.refuse_unsafe_delete(tmp / "scratch"), (tmp / "scratch").resolve())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_prepare_owned_dir_creates_marks_and_only_wipes_marked_directories(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            work = ci_common.prepare_owned_dir(tmp / "work")
            self.assertTrue((work / ci_common.OWNER_MARKER).is_file())
            (work / "old.txt").write_text("x")
            ci_common.prepare_owned_dir(tmp / "work")
            self.assertFalse((work / "old.txt").exists(), "a marked directory is replaced")
            foreign = tmp / "documents"
            foreign.mkdir()
            (foreign / "thesis.txt").write_text("keep")
            with self.assertRaises(ci_common.UnsafePath):
                ci_common.prepare_owned_dir(foreign)
            self.assertEqual((foreign / "thesis.txt").read_text(), "keep")
            empty = tmp / "empty"
            empty.mkdir()
            self.assertTrue(ci_common.prepare_owned_dir(empty).is_dir(), "an empty directory is fine")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


class RunLoggedOutputTests(unittest.TestCase):
    def test_an_error_in_the_middle_of_a_huge_log_is_never_lost(self):
        """Regression for the 'head + tail' false pass: 120,000 progress lines with one engine error in the middle."""
        code = ("import sys\n"
                "for i in range(120000):\n"
                "    print('progress %06d: importing resource number %d' % (i, i))\n"
                "    if i == 60000: print('SCRIPT ERROR: Parse Error: boom')\n")
        r = ci_common.run_logged([sys.executable, "-c", code], timeout=120)
        self.assertGreater(len(r.text), 5_000_000, "the whole stream is kept")
        self.assertFalse(r.overflow)
        self.assertEqual(godot_log.scan(r.text).errors, ["SCRIPT ERROR: Parse Error: boom"])

    def test_runaway_output_is_cut_off_killed_and_flagged(self):
        r = ci_common.run_logged([sys.executable, "-c", "import sys\nwhile True: sys.stdout.write('x' * 65536)"], timeout=60, max_bytes=500_000)
        self.assertTrue(r.overflow)
        self.assertFalse(r.timed_out)
        self.assertEqual(r.returncode, -1)
        self.assertLessEqual(len(r.text), 500_000)

    def test_log_file_parents_are_created(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            log = tmp / "a" / "b" / "c.log"
            ci_common.run_logged([sys.executable, "-c", "print('hi')"], log_path=log, timeout=30)
            self.assertIn("hi", log.read_text(encoding="utf-8"))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_godot_step_fails_closed_on_overflow(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            (tmp / "godot").write_text("fake")
            args = argparse.Namespace(godot=str(tmp / "godot"), log_dir=str(tmp / "logs"))
            res = ci_common.RunResult(-1, "ok\n", False, 0.1, overflow=True)
            with mock.patch("godot_ci.run_logged", return_value=res), contextlib.redirect_stdout(io.StringIO()) as out:
                with self.assertRaises(SystemExit) as cm:
                    godot_ci.run_godot_step("import", args, ["--headless"], 5)
            self.assertEqual(cm.exception.code, 1)
            self.assertIn("runaway output", out.getvalue())
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


class CommitIdStrictnessTests(unittest.TestCase):
    """An empty commit id (renamed or unset workflow variable) must be a usage error, never a silently skipped identity check."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.d = fake_export(self.tmp / "web")
        et.write_build_info(self.d, kind="game", env={"GITHUB_SHA": SHA}, godot_version="4.7.2", godot_version_string="4.7.2.stable.official.deadbeef0", project_dir=".", project_name="Shinobi Rush")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_require_sha40(self):
        self.assertEqual(et.require_sha40(SHA, "x"), SHA)
        for bad in ("", "abc", SHA.upper(), SHA + "0", None):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                et.require_sha40(bad, "x")

    def test_check_build_info_rejects_an_empty_expected_sha(self):
        with self.assertRaises(ValueError):
            et.check_build_info(self.d, kind="game", expect_sha="")
        self.assertEqual(et.check_build_info(self.d, kind="game", expect_sha=None), [], "omitting the option is allowed; passing an empty one is not")

    def test_cli_exits_2_for_an_empty_expect_sha_and_an_empty_commit_sha(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(godot_ci.main(["check-export", "--dir", str(self.d), "--kind", "game", "--expect-sha", ""]), 2)
            self.assertEqual(godot_ci.main(["check-export", "--dir", str(self.d), "--kind", "game", "--expect-sha", SHA]), 0)
            project = self.tmp / "proj"
            project.mkdir()
            (project / "project.godot").write_text("config_version=5\n")
            rc = godot_ci.main(["finalize-export", "--project", str(project), "--out", str(self.d), "--kind", "game", "--commit-sha", "", "--godot", str(project / "project.godot")])
            self.assertEqual(rc, 2)

    def test_a_self_test_fixture_can_never_be_exported_or_accepted_as_the_game(self):
        with self.assertRaises(ValueError):
            et.make_build_info(self.d, kind="game", env={"GITHUB_SHA": SHA}, godot_version="4.7.2", godot_version_string="x", project_dir=".", project_name=ci_common.SELFTEST_PROJECT_NAME)
        info = json.loads((self.d / "build-info.json").read_text(encoding="utf-8"))
        info["project_name"] = ci_common.SELFTEST_PROJECT_NAME  # a forged identity card claiming kind=game
        (self.d / "build-info.json").write_text(json.dumps(info), encoding="utf-8")
        self.assertTrue(any("self-test fixture" in f.message for f in et.check_build_info(self.d, kind="game")))

    def test_output_path_options_create_their_parent_directories(self):
        project = self.tmp / "p"
        project.mkdir()
        (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="X"\nrun/main_scene="res://m.tscn"\n')
        target = self.tmp / "deep" / "er" / "report.json"
        with contextlib.redirect_stdout(io.StringIO()):
            v.main(["--project", str(project), "--json-out", str(target), "--engine-version", "4.7"])
        self.assertTrue(target.is_file())
        out = self.tmp / "x" / "y" / "export"
        args = argparse.Namespace(project=str(project), godot=str(self.tmp / "godot"), log_dir=str(self.tmp / "l" / "o" / "gs"), out=str(out))
        (self.tmp / "godot").write_text("fake")
        res = ci_common.RunResult(0, "[ DONE ] reimport\n", False, 0.1)
        with mock.patch("godot_ci.run_logged", return_value=res), contextlib.redirect_stdout(io.StringIO()):
            godot_ci.cmd_export(args)
        self.assertTrue(out.is_dir(), "export --out is created with its parents before Godot runs")


class SelfTestHarnessTests(unittest.TestCase):
    """The self-test must not be able to pass vacuously."""

    class FakeCtx:
        def __init__(self, py_result):
            self.py_result, self.results = py_result, []

        def build_fixture(self, variant):
            return Path(tempfile.gettempdir()) / variant

        work = Path(tempfile.gettempdir())

        def py(self, *args, **kwargs):
            return self.py_result

        def expect(self, case, step, ok, detail):
            self.results.append({"case": case, "step": step, "ok": bool(ok), "detail": detail})

    def run_static(self, rc, text):
        ctx = self.FakeCtx((rc, text))
        selftest.static_case("missing_main_scene", "PRJ004")(ctx)
        return ctx.results

    def test_a_negative_case_that_does_not_fail_is_a_failure(self):
        self.assertFalse(self.run_static(0, "validate_godot_project: PASS - 0 error(s)")[0]["ok"])

    def test_a_negative_case_that_fails_for_the_wrong_reason_or_with_a_usage_error_is_a_failure(self):
        self.assertFalse(self.run_static(1, "ERROR PRJ003 something else")[0]["ok"])
        self.assertFalse(self.run_static(2, "usage: PRJ004 appears in the usage text")[0]["ok"], "exit 2 is an infrastructure error, not an expected failure")

    def test_a_negative_case_that_fails_for_the_right_reason_passes(self):
        self.assertTrue(self.run_static(1, "ERROR   PRJ004 project.godot: Main scene missing")[0]["ok"])

    class SmokeCtx(FakeCtx):
        """A browser-negative case whose build steps succeed and whose smoke run reports the given check statuses and details."""

        def __init__(self, checks, details):
            super().__init__((0, ""))
            self.checks, self.details = checks, details

        def ci(self, *args, **kwargs):
            return 0, ""

        def export_selftest(self, project, tool=None):
            return True, Path(tempfile.gettempdir())

        def smoke(self, name, export_dir, *extra):
            return 1, self.checks, ""

    def run_browser_negative(self, case, checks, details):
        ctx = self.SmokeCtx(checks, details)
        selftest.browser_negative(case, *selftest.BROWSER_NEGATIVES[case])(ctx)
        self.assertEqual(len(ctx.results), 1)
        return ctx.results[0]["ok"]

    def test_a_browser_negative_must_fail_for_the_injected_fault_not_for_another_reason(self):
        """Review F1: the named check must fail, its detail must name the injected fault, and the unrelated checks must still pass."""
        passing = {"engine-start": "pass", "canvas-visible": "pass", "no-fatal-console": "fail"}
        fault = {"no-fatal-console": "1 fatal event(s); first: [godot-error] ERROR: SELFTEST_INTENTIONAL_STARTUP_ERROR"}
        self.assertTrue(self.run_browser_negative("startup_error", passing, fault))
        self.assertFalse(self.run_browser_negative("startup_error", passing, {"no-fatal-console": "1 fatal event(s); first: [pageerror] some other error"}),
                         "right check, wrong cause")
        self.assertFalse(self.run_browser_negative("startup_error", dict(passing, **{"engine-start": "fail"}), fault), "an unrelated check failed too")
        self.assertFalse(self.run_browser_negative("startup_error", dict(passing, **{"no-fatal-console": "pass"}), fault), "the named check did not fail")
        self.assertFalse(self.run_browser_negative("startup_error", {}, {}), "no smoke-result.json at all")

    def test_every_browser_negative_names_a_check_a_fault_and_the_checks_that_must_still_pass(self):
        for case, (must_fail, evidence, must_pass) in selftest.BROWSER_NEGATIVES.items():
            self.assertIn(case, selftest.EXPECTED_COUNTS)
            self.assertTrue(must_fail and evidence and must_pass, case)
            self.assertNotIn(must_fail, must_pass, case)

    def test_every_case_has_an_expected_count_and_vice_versa(self):
        self.assertEqual(set(selftest.CASES), set(selftest.EXPECTED_COUNTS))
        self.assertEqual(selftest.ALL_CASES, list(selftest.EXPECTED_COUNTS))
        self.assertTrue(all(n >= 1 for n in selftest.EXPECTED_COUNTS.values()))

    def test_completeness_flags_missing_extra_and_skipped_expectations(self):
        full = [{"case": "a", "ok": True}, {"case": "a", "ok": True}, {"case": "b", "ok": True}]
        self.assertEqual(selftest.completeness_problems(full, ["a", "b"], {"a": 2, "b": 1}), [])
        self.assertEqual(len(selftest.completeness_problems(full[:2], ["a", "b"], {"a": 2, "b": 1})), 1, "case b never recorded anything")
        self.assertEqual(len(selftest.completeness_problems(full, ["a", "b"], {"a": 3, "b": 1})), 1, "an assertion was dropped from a")
        self.assertEqual(len(selftest.completeness_problems(full + [{"case": "b", "ok": True}], ["a", "b"], {"a": 2, "b": 1})), 1)

    def run_main(self, *argv):
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            rc = selftest.main(list(argv))
        return rc, err.getvalue()

    def test_usage_errors_exit_2_before_anything_is_deleted_or_run(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            foreign = tmp / "documents"
            foreign.mkdir()
            (foreign / "thesis.txt").write_text("keep")
            common = ["--godot-dir", str(tmp / "godot"), "--evidence-dir", str(tmp / "ev")]
            self.assertEqual(self.run_main(*common, "--work-dir", str(tmp / "w"), "--cases", "nope")[0], 2, "unknown case id")
            self.assertEqual(self.run_main(*common, "--work-dir", str(tmp / "w"), "--cases", "")[0], 2, "empty case list")
            self.assertEqual(self.run_main(*common, "--work-dir", str(foreign))[0], 2, "foreign non-empty work dir")
            self.assertEqual((foreign / "thesis.txt").read_text(), "keep")
            self.assertEqual(self.run_main("--godot-dir", str(tmp / "godot"), "--evidence-dir", str(tmp / "ev"), "--work-dir", str(REPO_ROOT / "scratch"))[0], 2, "inside the repository")
            self.assertFalse((REPO_ROOT / "scratch").exists())
            self.assertEqual(self.run_main("--godot-dir", str(tmp / "godot"), "--evidence-dir", str(REPO_ROOT / "ev"), "--work-dir", str(tmp / "w"))[0], 2)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_no_workflow_runs_a_partial_self_test(self):
        for wf in (REPO_ROOT / ".github" / "workflows").glob("*.yml"):
            text = wf.read_text(encoding="utf-8")
            if "selftest.py" in text:
                self.assertNotIn("--cases", text, f"{wf.name}: a partial self-test must never stand in for the full one")


if __name__ == "__main__":
    unittest.main()
