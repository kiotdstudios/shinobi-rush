import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

from helpers import REPO_ROOT

import check_workflows as cw
import pins as pinlib
import validate_godot_project as v


# LF is only enforced where checkout == blobs (CI). A Windows working tree with core.autocrlf=true legitimately holds CRLF.
CI_MODE = os.environ.get("GITHUB_ACTIONS") == "true"


def copy_repo_ci(dest: Path) -> Path:
    """Copy exactly the files check_workflows looks at into a scratch root."""
    for rel in (".github/workflows", "scripts/ci", "docs/development"):
        src = REPO_ROOT / rel
        if src.exists():
            shutil.copytree(src, dest / rel, ignore=shutil.ignore_patterns("node_modules", "__pycache__", "tests"), dirs_exist_ok=True)
    for name in (".gitattributes", ".gitignore"):
        if (REPO_ROOT / name).exists():
            shutil.copy(REPO_ROOT / name, dest / name)
    return dest


class RepositoryDefinitionTests(unittest.TestCase):
    def test_the_repositorys_own_ci_definition_passes_every_rule(self):
        pins = pinlib.load(REPO_ROOT / "scripts" / "ci" / "godot-version.env")
        problems = []
        for wf in sorted((REPO_ROOT / ".github" / "workflows").glob("*.yml")):
            problems += cw.check_workflow(wf, pins, ci_mode=CI_MODE)
        problems += cw.check_playwright_consistency(pins) + cw.check_docs(pins, write=False)
        self.assertEqual(problems, [], "\n".join(f"{p.path}:{p.line} {p.code} {p.message}" for p in problems))

    def test_the_handoff_document_lists_every_gdignore_folder_the_validator_checks(self):
        """Stage 2 adds an empty .gdignore to each of these folders; the validator (PRJ012), the handoff document and the
        self-test generator must agree on the list, and the document must say the repository root is the convention."""
        self.assertEqual(v.NON_GAME_DIRS, ("docs", "orders", "skills", "world", "scripts/ci", "assets/characters/player/references"))
        handoff = (REPO_ROOT / "docs" / "development" / "GODOT_PROJECT_HANDOFF.md").read_text(encoding="utf-8")
        for folder in v.NON_GAME_DIRS:
            self.assertIn(f"`{folder}`", handoff, f"{folder} is missing from the .gdignore list of the handoff document")
        self.assertIn("section 11", handoff)
        self.assertIn("the repository root IS the Godot project", handoff)
        self.assertIn("only change under `assets/`", handoff)  # the one assets/ exception stays documented

    def test_the_godot_import_cache_is_ignored_and_never_cached_or_uploaded(self):
        """Repo-root layout: `.godot/` sits in the checkout root next to docs/ and scripts/. It must be git-ignored, and no workflow
        may cache or upload it (every run imports from scratch); generated output goes to RUNNER_TEMP, never into the checkout."""
        ignore = [ln.strip() for ln in (REPO_ROOT / ".gitignore").read_text(encoding="utf-8").splitlines()]
        for rule in (".godot/", "exports/*", "node_modules/", "godot-ci-logs/"):
            self.assertIn(rule, ignore, f".gitignore lacks {rule}")
        for wf in sorted((REPO_ROOT / ".github" / "workflows").glob("*.yml")):
            for n, line in enumerate(wf.read_text(encoding="utf-8").splitlines(), 1):
                if line.strip().startswith(("path:", "- path:", "key:")):
                    self.assertNotIn(".godot", line, f"{wf.name}:{n} caches or uploads the Godot import cache")
                    self.assertNotIn("GITHUB_WORKSPACE", line, f"{wf.name}:{n} writes generated output into the checkout")
        build = (REPO_ROOT / ".github" / "workflows" / "godot-ci.yml").read_text(encoding="utf-8")
        self.assertIn('echo "EXPORT_DIR=${RUNNER_TEMP}/web-export"', build)
        self.assertIn('echo "EVIDENCE_DIR=${RUNNER_TEMP}/evidence"', build)

    def test_the_required_check_job_ids_still_exist(self):
        repo_checks = (REPO_ROOT / ".github" / "workflows" / "repository-checks.yml").read_text(encoding="utf-8")
        self.assertRegex(repo_checks, r"(?m)^  validate-orders-and-project:\s*$")
        self.assertNotRegex(repo_checks, r"(?m)^\s+(paths|paths-ignore):")


class LintHelperTests(unittest.TestCase):
    def test_run_blocks_join_folded_and_continued_commands(self):
        lines = ["      - name: x", "        run: >-", "          python3 scripts/ci/a.py", "          --one 1", "          --two 2", "      - run: echo hi",
                 "      - name: y", "        run: |", "          python3 scripts/ci/b.py \\", "            --three 3", "          echo done"]
        blocks = cw.run_blocks(lines)
        self.assertEqual(blocks[0][1], ["python3 scripts/ci/a.py --one 1 --two 2"])
        self.assertEqual(blocks[1][1], ["echo hi"])
        self.assertEqual(blocks[2][1], ["python3 scripts/ci/b.py --three 3", "echo done"])

    def test_flags_stop_at_shell_operators(self):
        self.assertEqual(cw.flags_of(' github-env >> "$GITHUB_ENV" --not-a-flag'), [])
        self.assertEqual(cw.flags_of(' --a x --b "y" && echo --c'), ["--a", "--b"])

    def test_expressions_compare_without_whitespace_noise(self):
        self.assertEqual(cw.normalize_expr("${{  a   &&\n b }}"), "a && b")
        self.assertEqual(cw.name_set("[detect, build ,x]"), {"detect", "build", "x"})


class RuleMutationTests(unittest.TestCase):
    """Every rule must fire on a deliberately broken copy of the real workflows."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="cw-"))
        self.root = copy_repo_ci(self.tmp / "repo")
        self.pins = pinlib.load(self.root / "scripts" / "ci" / "godot-version.env")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def codes_after(self, workflow, fn):
        path = self.root / ".github" / "workflows" / workflow
        original = path.read_text(encoding="utf-8")
        mutated = fn(original)
        self.assertNotEqual(original, mutated, "mutation did not change the file")
        path.write_text(mutated, encoding="utf-8", newline="\n")
        try:
            return {p.code for p in cw.check_workflow(path, self.pins, ci_mode=True)}
        finally:
            path.write_text(original, encoding="utf-8", newline="\n")

    def test_rules(self):
        cases = [
            ("WF004", "godot-ci.yml", lambda t: t.replace("actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0", "actions/cache@v6", 1)),
            ("WF004", "godot-ci.yml", lambda t: t.replace(" # v6.1.0", "", 1)),
            ("WF005", "godot-ci.yml", lambda t: t.replace("runs-on: ubuntu-24.04", "runs-on: ubuntu-latest", 1)),
            ("WF002", "godot-ci.yml", lambda t: t.replace("permissions:\n  contents: read\nconcurrency", "concurrency", 1)),
            ("WF003", "pipeline-self-test.yml", lambda t: t.replace("permissions:\n  contents: read\nconcurrency", "permissions:\n  contents: write\nconcurrency", 1)),
            ("WF006", "godot-ci.yml", lambda t: t.replace("  pull_request:\n", "  pull_request_target:\n", 1)),
            ("WF007", "godot-ci.yml", lambda t: t.replace("${{ vars.GODOT_PROJECT_DIR }}", "${{ secrets.TOKEN }}", 1)),
            ("WF008", "godot-ci.yml", lambda t: t.replace("    timeout-minutes: 5\n", "", 1)),
            ("WF009", "godot-ci.yml", lambda t: t.replace("          persist-credentials: false\n", "", 1)),
            ("WF010", "godot-ci.yml", lambda t: t.replace("run: python3 scripts/ci/check_workflows.py", "run: echo ${{ github.event.pull_request.title }}", 1)),
            ("WF011", "godot-ci.yml", lambda t: t.replace("  workflow_dispatch:\n", "  workflow_dispatch:\n    inputs:\n      x:\n        type: string\n", 1)),
            ("WF012", "godot-ci.yml", lambda t: t.replace("  pull_request:\n", "  pull_request:\n    paths:\n      - 'x'\n", 1)),
            ("WF013", "godot-ci.yml", lambda t: t.replace("  godot-ci-gate:", "  gate:", 1)),
            ("WF014", "godot-ci.yml", lambda t: t.replace("      id-token: write\n", "", 1)),
            ("WF014", "godot-ci.yml", lambda t: t.replace("needs.build.result == 'success' && ", "", 1)),  # a gate result is no longer named
            ("WF014", "godot-ci.yml", lambda t: t.replace("if: ${{ needs.detect.outputs.project_found == 'true' && needs.build.result", "if: ${{ always() && needs.detect.outputs.project_found == 'true' && needs.build.result", 1)),
            ("WF014", "godot-ci.yml", lambda t: t.replace("needs: [detect, build, smoke-predeploy]", "needs: [detect, build]", 1)),
            ("WF014", "godot-ci.yml", lambda t: t.replace(" && needs.deploy.result == 'success' }}", " }}", 1)),  # smoke-postdeploy no longer waits for deploy
            ("WF015", "pipeline-self-test.yml", lambda t: t.replace("  e2e:\n    name:", "  e2e:\n    environment: github-pages\n    name:", 1)),
            ("WF015", "godot-ci.yml", lambda t: t.replace("  build:\n    name:", "  build:\n    permissions:\n      id-token: write\n    name:", 1)),
            ("WF016", "pipeline-self-test.yml", lambda t: t.replace('--evidence-dir "$SELFTEST_EVIDENCE_DIR"', '--evidence-dir "$SELFTEST_EVIDENCE_DIR" --cases good', 1)),
            ("WF017", "godot-ci.yml", lambda t: t.replace('--log-dir "$EVIDENCE_DIR/logs"', '--log_dir "$EVIDENCE_DIR/logs"', 1)),
            ("WF017", "godot-ci.yml", lambda t: t.replace("scripts/ci/pages_gate.py gate", "scripts/ci/pages_gates.py gate", 1)),
            ("WF017", "godot-ci.yml", lambda t: t.replace('--serve-dir "$EXPORT_DIR"', '--serve-directory "$EXPORT_DIR"', 1)),
            ("WF018", "godot-ci.yml", lambda t: t.replace("    timeout-minutes: 45\n", "    timeout-minutes: 45\n    continue-on-error: true\n", 1)),
            ("WF018", "godot-ci.yml", lambda t: t.replace("run: python3 scripts/ci/check_workflows.py", "run: python3 scripts/ci/check_workflows.py || true", 1)),
            ("WF019", "godot-ci.yml", lambda t: t.replace("          GODOT_PROJECT_DIR: ${{ vars.GODOT_PROJECT_DIR }}\n", "          GODOT_PROJECT_DIR: ${{ vars.GODOT_PROJECT_DIR }}\n          SHINOBI_ALLOW_SELFTEST_PROJECT: '1'\n", 1)),
            ("WF001", "repository-checks.yml", lambda t: "\ufeff" + t),
        ]
        for code, workflow, fn in cases:
            with self.subTest(code=code, workflow=workflow):
                self.assertIn(code, self.codes_after(workflow, fn))

    def test_playwright_pin_drift_is_caught(self):
        pj = self.root / "scripts" / "ci" / "smoke" / "package.json"
        data = json.loads(pj.read_text(encoding="utf-8"))
        data["dependencies"]["playwright"] = "^1.64.1"
        pj.write_text(json.dumps(data), encoding="utf-8")
        old_root = cw.HERE
        try:
            cw.HERE = self.root / "scripts" / "ci"
            self.assertTrue(any(p.code == "PIN002" for p in cw.check_playwright_consistency(self.pins)))
        finally:
            cw.HERE = old_root

    def test_stale_doc_marker_is_caught_and_fixed_by_write(self):
        doc = self.root / "docs" / "development" / "GODOT_PROJECT_HANDOFF.md"
        doc.write_text(doc.read_text(encoding="utf-8").replace("`4.7.2`", "`4.6.0`"), encoding="utf-8")
        old_root = cw.ROOT
        try:
            cw.ROOT = self.root
            self.assertTrue(any(p.code == "DOC001" for p in cw.check_docs(self.pins, write=False)))
            self.assertEqual(cw.check_docs(self.pins, write=True), [])
            self.assertIn("`4.7.2`", doc.read_text(encoding="utf-8"))
        finally:
            cw.ROOT = old_root


if __name__ == "__main__":
    unittest.main()
