import argparse
import io
import json
import shutil
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest import mock

import helpers  # noqa: F401  (puts scripts/ci on sys.path)
import ci_common
import godot_ci

SHA = "a" * 40
HEAD = "b" * 40


class ProjectBuildInfoTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.project = self.tmp / "proj"
        self.project.mkdir()
        (self.project / "project.godot").write_text("config_version=5\n")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_fields_and_identity_only(self):
        env = {"GITHUB_SHA": SHA, "PR_HEAD_SHA": HEAD, "GITHUB_RUN_ID": "42", "GITHUB_RUN_ATTEMPT": "2",
               "GITHUB_REF": "refs/pull/9/merge", "GITHUB_REPOSITORY": "o/r"}
        info = godot_ci.project_build_info(env, "4.7.2")
        self.assertEqual({k: info[k] for k in ("commit_sha", "head_sha", "run_id", "run_attempt", "ref", "repository", "godot_version")},
                         {"commit_sha": SHA, "head_sha": HEAD, "run_id": "42", "run_attempt": "2", "ref": "refs/pull/9/merge",
                          "repository": "o/r", "godot_version": "4.7.2-stable"})
        self.assertRegex(info["built_at"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
        self.assertNotIn("files", info)  # hashes live only in the served build-info.json

    def test_env_fallbacks(self):
        info = godot_ci.project_build_info({"GITHUB_SHA": SHA}, "4.7.2")
        self.assertEqual(info["head_sha"], SHA)
        for k in ("run_id", "run_attempt", "ref", "repository"):
            self.assertEqual(info[k], "")

    def test_bad_sha_is_rejected(self):
        for bad in ("", "abc", "g" * 40):
            with self.subTest(sha=bad), self.assertRaises(ValueError):
                godot_ci.project_build_info({"GITHUB_SHA": bad}, "4.7.2")

    def test_file_exists_during_action_and_is_removed_on_success(self):
        seen = {}

        def action():
            seen["data"] = json.loads((self.project / "build-info.json").read_text(encoding="utf-8"))
            return "ok"

        result, written = godot_ci.run_with_project_build_info(self.project, {"GITHUB_SHA": SHA}, "4.7.2", action)
        self.assertEqual((result, written), ("ok", True))
        self.assertEqual(seen["data"]["commit_sha"], SHA)
        self.assertFalse((self.project / "build-info.json").exists())

    def test_file_is_removed_when_the_action_raises_or_exits(self):
        for exc in (RuntimeError("boom"), SystemExit(1)):
            with self.subTest(exc=type(exc).__name__):
                def action():
                    raise exc
                with self.assertRaises(type(exc)):
                    godot_ci.run_with_project_build_info(self.project, {"GITHUB_SHA": SHA}, "4.7.2", action)
                self.assertFalse((self.project / "build-info.json").exists())

    def test_without_github_sha_nothing_is_written(self):
        seen = {}
        result, written = godot_ci.run_with_project_build_info(
            self.project, {}, "4.7.2", lambda: seen.setdefault("exists", (self.project / "build-info.json").exists()))
        self.assertFalse(written)
        self.assertFalse(seen["exists"])

    def test_existing_file_is_never_overwritten_or_deleted(self):
        (self.project / "build-info.json").write_text("mine", encoding="utf-8")
        with self.assertRaises(ValueError):
            godot_ci.run_with_project_build_info(self.project, {"GITHUB_SHA": SHA}, "4.7.2", lambda: None)
        self.assertEqual((self.project / "build-info.json").read_text(encoding="utf-8"), "mine")

    def test_only_the_project_dir_is_written(self):
        before = {p.relative_to(self.tmp) for p in self.tmp.rglob("*")}
        written_paths = []
        godot_ci.run_with_project_build_info(
            self.project, {"GITHUB_SHA": SHA}, "4.7.2",
            lambda: written_paths.extend(p.relative_to(self.tmp) for p in self.tmp.rglob("*") if p.relative_to(self.tmp) not in before))
        self.assertEqual(written_paths, [Path("proj") / "build-info.json"])
        self.assertEqual({p.relative_to(self.tmp) for p in self.tmp.rglob("*")}, before)

    def test_cmd_export_bakes_then_cleans_on_success_and_failure(self):
        args = argparse.Namespace(project=str(self.project), godot=str(self.tmp / "godot"), log_dir=str(self.tmp / "logs"),
                                  out=str(self.tmp / "out"))
        (self.tmp / "godot").write_text("fake")
        seen = {}

        def run(cmd, log_path=None, timeout=None, **kw):
            seen["baked"] = json.loads((self.project / "build-info.json").read_text(encoding="utf-8"))["commit_sha"]
            return ci_common.RunResult(0, "[ DONE ] reimport\n", False, 0.1)

        with mock.patch.dict("os.environ", {"GITHUB_SHA": SHA}), mock.patch("godot_ci.run_logged", side_effect=run), redirect_stdout(io.StringIO()):
            godot_ci.cmd_export(args)
        self.assertEqual(seen["baked"], SHA)
        self.assertFalse((self.project / "build-info.json").exists())
        shutil.rmtree(self.tmp / "out", ignore_errors=True)
        failing = ci_common.RunResult(1, "ERROR: Project export for preset \"Web\" failed.\n", False, 0.1)
        with mock.patch.dict("os.environ", {"GITHUB_SHA": SHA}), mock.patch("godot_ci.run_logged", return_value=failing), \
                redirect_stdout(io.StringIO()), self.assertRaises(SystemExit):
            godot_ci.cmd_export(args)
        self.assertFalse((self.project / "build-info.json").exists())


if __name__ == "__main__":
    unittest.main()
