#!/usr/bin/env python3
"""Pipeline self-test: proves the Godot CI tooling works AND that it rejects deliberately broken projects.

TOOLING VERIFICATION ONLY. Throwaway Godot projects are generated at runtime in --work-dir (never inside the
repository, never committed, never uploaded to Pages, never described as the game). Every case drives the same
command lines the workflows use and asserts that the RIGHT step fails with the RIGHT evidence (a negative case that
fails for the wrong reason is itself a failure).

  python3 scripts/ci/selftest.py --godot-dir DIR --work-dir DIR --evidence-dir DIR [--cases good,threads_enabled]

A full run must execute every case in ALL_CASES and record exactly EXPECTED_COUNTS[case] expectations for each, so a
dropped case, a dropped assertion or a typo can never make the self-test pass vacuously. `--cases` is for local
debugging only: the run is then labelled PARTIAL and check_workflows.py forbids it in the workflows.
Exit codes: 0 all expectations met | 1 an expectation was not met | 2 usage error (unknown case, unsafe directory)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable, Dict, List, Optional, Sequence, Tuple

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import export_tools  # noqa: E402
import install_godot  # noqa: E402
import pins as pinlib  # noqa: E402
import selftest_project as sp  # noqa: E402
from ci_common import ALLOW_SELFTEST_ENV, REPO_ROOT, UnsafePath, annotate, prepare_owned_dir, write_summary  # noqa: E402

SELFTEST_SHA = "5e1f7e575e1f7e575e1f7e575e1f7e575e1f7e57"  # fake but well-formed 40-hex commit id
SMOKE_DIR = HERE / "smoke"
STRICT_SMOKE = ["--input-sequence", "ArrowRight:150", "--require-input-effect", "--require-ready-hook", "--startup-timeout-ms", "30000", "--settle-ms", "1500"]
# case -> (check that must fail, regex its recorded detail must match = the injected fault, checks that must still pass)
BROWSER_NEGATIVES: Dict[str, Tuple[str, str, Tuple[str, ...]]] = {
    "startup_script_error": ("no-fatal-console", r"Nonexistent function 'selftest_nonexistent_method'", ("engine-start", "canvas-visible")),
    "startup_error": ("no-fatal-console", r"SELFTEST_INTENTIONAL_STARTUP_ERROR", ("engine-start", "canvas-visible")),
    "page_error": ("no-fatal-console", r"\[pageerror\] SELFTEST_PAGE_ERROR", ("engine-start", "canvas-visible")),
    "blank_canvas": ("canvas-not-blank", r"uniform", ("engine-start", "canvas-visible", "no-fatal-console")),
}
# case -> number of expectations it must record. Keep in sync with the case bodies (a unit test enforces the key set).
EXPECTED_COUNTS: Dict[str, int] = {
    "good": 8,
    "forward_plus_base": 5,
    "repo_shaped_layout": 8,
    "threads_enabled": 1,
    "missing_main_scene": 1,
    "no_main_scene": 1,
    "web_renderer_override": 1,
    "gdignore_scripts": 1,
    "selftest_fixture_refused": 1,
    "parse_error": 1,
    "parse_error_referenced": 1,
    "startup_script_error": 1,
    "startup_error": 1,
    "page_error": 1,
    "blank_canvas": 1,
    "threads_enabled_export": 3,
}
ALL_CASES = list(EXPECTED_COUNTS)


class Ctx:
    def __init__(self, args: argparse.Namespace, pins: Dict[str, str]) -> None:
        self.work, self.evidence = args.work_dir.resolve(), args.evidence_dir.resolve()
        self.platform = "windows" if os.name == "nt" else "linux"
        self.godot = str(install_godot.binary_path(args.godot_dir.resolve(), self.platform, pins["GODOT_VERSION"]))
        # ALLOW_SELFTEST_ENV lets the validators accept the generated fixtures' "(not the game)" project name; it is
        # set for these child processes only, never in a workflow.
        self.env = dict(os.environ, GODOT_BIN=self.godot, GITHUB_SHA=SELFTEST_SHA, **{ALLOW_SELFTEST_ENV: "1"})
        self.results: List[dict] = []
        self.details: Dict[str, str] = {}  # check name -> detail of the most recent smoke run (the cause, not just the status)

    def run(self, argv: List[str], cwd: Optional[Path] = None, timeout: int = 900, env: Optional[Dict[str, str]] = None) -> Tuple[int, str]:
        p = subprocess.run(argv, cwd=cwd, env=self.env if env is None else env, capture_output=True, timeout=timeout)
        return p.returncode, (p.stdout + b"\n" + p.stderr).decode("utf-8", "replace")

    def py(self, script: str, *args: str, tool: Path = HERE) -> Tuple[int, str]:
        return self.run([sys.executable, str(tool / script), *args])

    def ci(self, sub: str, project: Path, *extra: str, tool: Path = HERE) -> Tuple[int, str]:
        return self.py("godot_ci.py", sub, "--project", str(project), "--log-dir", str(self.evidence / project.name / "logs"), *extra, tool=tool)

    def smoke(self, name: str, export_dir: Path, *extra: str) -> Tuple[int, Dict[str, str], str]:
        out = self.evidence / name / "smoke"
        rc, text = self.run(["node", "smoke.mjs", "--serve-dir", str(export_dir), "--out-dir", str(out), "--label", name, "--expected-kind", "selftest",
                             "--expected-sha", SELFTEST_SHA, *STRICT_SMOKE, *extra], cwd=SMOKE_DIR, timeout=600)
        try:
            listed = json.loads((out / "smoke-result.json").read_text(encoding="utf-8"))["checks"]
            checks = {c["name"]: c["status"] for c in listed}
            self.details = {c["name"]: str(c.get("detail", "")) for c in listed}
        except (OSError, ValueError):
            checks, self.details = {}, {}
        return rc, checks, text

    def expect(self, case: str, step: str, ok: bool, detail: str) -> None:
        self.results.append({"case": case, "step": step, "ok": bool(ok), "detail": detail[:400]})
        print(f"[selftest] {'PASS' if ok else 'FAIL'} {case} / {step}: {detail[:200]}", flush=True)

    def build_fixture(self, variant: str) -> Path:
        return sp.write_project(self.work / variant, variant)

    def copy_tooling_into(self, project: Path) -> Path:
        """Copy the CI tooling to <project>/scripts/ci, the layout of a real repository whose Godot project is the repo root.
        The .gdignore models the stage-2 end state; this repository's stage 1 commits none (the generator already wrote it)."""
        dest = project / "scripts" / "ci"
        shutil.copytree(HERE, dest, ignore=shutil.ignore_patterns("tests", "node_modules", "__pycache__", "smoke"), dirs_exist_ok=True)
        (dest / ".gdignore").write_bytes(b"")
        return dest

    def export_selftest(self, project: Path, tool: Path = HERE) -> Tuple[bool, Path]:
        out = self.work / f"{project.name}-export"
        shutil.rmtree(out, ignore_errors=True)  # always a sub-directory of the owned work dir
        rc1, _ = self.ci("export", project, "--out", str(out), tool=tool)
        rc2, _ = self.ci("finalize-export", project, "--out", str(out), "--kind", "selftest", "--commit-sha", SELFTEST_SHA, tool=tool)
        return rc1 == 0 and rc2 == 0, out


def case_good(c: Ctx) -> None:
    p = c.build_fixture("good")
    rc, text = c.py("validate_godot_project.py", "--project", str(p), "--repo-root", str(c.work))
    c.expect("good", "validate-project", rc == 0, f"rc={rc}")
    rc, text = c.ci("import", p)
    c.expect("good", "import", rc == 0, f"rc={rc}")
    rc, text = c.ci("validate-resources", p)
    c.expect("good", "validate-resources", rc == 0, f"rc={rc}")
    rc, text = c.ci("tests", p)
    c.expect("good", "tests (none present -> loud warning, exit 0)", rc == 0 and "No GDScript test framework found" in text, f"rc={rc}")
    ok, out = c.export_selftest(p)
    c.expect("good", "export + finalize-export", ok, str(out))
    rc, text = c.py("godot_ci.py", "check-export", "--dir", str(out), "--kind", "selftest", "--expect-sha", SELFTEST_SHA)
    c.expect("good", "check-export (kind=selftest)", rc == 0, f"rc={rc}")
    rc, text = c.py("godot_ci.py", "check-export", "--dir", str(out), "--kind", "game")
    c.expect("good", "deploy guard: a selftest export is refused as 'game'", rc == 1 and "must never be deployed" in text, f"rc={rc}")
    rc, checks, text = c.smoke("good", out)
    c.expect("good", "browser smoke (strict)", rc == 0 and checks.get("no-fatal-console") == "pass", f"rc={rc} checks={checks}")


def case_forward_plus_base(c: Ctx) -> None:
    """The desktop renderer is a product decision. A Forward+ project must pass CI (warning only): the Web build is Compatibility anyway."""
    name = "forward_plus_base"
    p = c.build_fixture(name)
    rc, text = c.py("validate_godot_project.py", "--project", str(p), "--repo-root", str(c.work))
    c.expect(name, "validate-project passes with a PRJ005 warning and no error", rc == 0 and "PRJ005" in text and "PASS - 0 error(s)" in text, f"rc={rc}")
    rc, _ = c.ci("import", p)
    c.expect(name, "import", rc == 0, f"rc={rc}")
    rc, _ = c.ci("validate-resources", p)
    c.expect(name, "validate-resources", rc == 0, f"rc={rc}")
    ok, out = c.export_selftest(p)
    c.expect(name, "export + finalize-export (Web forces Compatibility)", ok, str(out))
    rc, checks, _ = c.smoke(name, out)
    c.expect(name, "browser smoke (strict); engine-evidence confirms the runtime Compatibility renderer", rc == 0 and checks.get("engine-evidence") == "pass", f"rc={rc} checks={checks}")


def walker_result(text: str) -> Tuple[Optional[Tuple[int, int]], List[str]]:
    """(scripts, scenes) and the res:// folders that were not walked, parsed from `godot_ci.py validate-resources` output."""
    m = re.search(r"validated (\d+) scripts, (\d+) scenes", text)
    s = re.search(r"^not walked: (.*)$", text, re.M)
    return (int(m.group(1)), int(m.group(2))) if m else None, [x.strip() for x in s.group(1).split(",")] if s else []


# Folders the resource walker must report as not walked in the repo-root layout: dot folders (.agents, .godot), node_modules
# and exports (by name/path), the folders that carry a .gdignore (docs, orders, skills, world, the references folder) and
# scripts/ci (a .gdignore here, and skipped by rule as well).
WALKER_SKIPS = ["res://.agents", "res://.godot", "res://assets/characters/player/references", "res://docs", "res://exports", "res://node_modules",
                "res://orders", "res://scripts/ci", "res://skills", "res://world"]


def case_repo_shaped_layout(c: Ctx) -> None:
    """The project at the REPOSITORY ROOT (the convention: section 11 of the prototype brief), next to folders full of images:
    game code under scripts/player and the game art are imported and packed; docs/orders/skills/world, the approved
    turnaround (assets/characters/player/references) and the CI tooling carry a .gdignore and are neither imported nor packed;
    a control folder WITHOUT .gdignore proves the checks can see images; the resource walker skips every folder it must skip;
    the CI tooling runs from inside the checkout."""
    name = "repo_shaped_layout"
    p = sp.write_project(c.work / "repo_shaped", "repo_shaped")
    tool = c.copy_tooling_into(p)
    rc, text = c.py("validate_godot_project.py", "--project", str(p), "--repo-root", str(p), tool=tool)
    c.expect(name, "validate-project (project == repo root): no PRJ012 and no PRJ013", rc == 0 and "PRJ012" not in text and "PRJ013" not in text, f"rc={rc}")
    rc, _ = c.ci("import", p, tool=tool)
    c.expect(name, "import", rc == 0, f"rc={rc}")
    imported = sorted(f.name for f in (p / ".godot" / "imported").glob("*")) if (p / ".godot" / "imported").is_dir() else []
    got = [Path(sp.GAME_ART).name, Path(sp.CONTROL_IMAGE).name]
    ignored = [Path(r).name for r in sp.IGNORED_IMAGES]
    c.expect(name, "import honoured the .gdignore files: the game art and the control image were imported, no ignored image was",
             all(any(f.startswith(g + "-") for f in imported) for g in got) and not any(f.startswith(i + "-") for f in imported for i in ignored), f"imported={imported}")
    rc, text = c.ci("validate-resources", p, tool=tool)
    counts, skipped = walker_result(text)
    c.expect(name, f"validate-resources walks exactly the {sp.GAME_SCRIPT_COUNT} game scripts and 1 scene and skips the ignored, dot, node_modules, exports and scripts/ci folders (invalid decoy scripts there are never loaded)",
             rc == 0 and counts == (sp.GAME_SCRIPT_COUNT, 1) and all(s in skipped for s in WALKER_SKIPS), f"rc={rc} counts={counts} skipped={skipped}")
    ok, out = c.export_selftest(p, tool=tool)
    c.expect(name, "export + finalize-export", ok, str(out))
    pck = (out / "index.pck").read_bytes() if (out / "index.pck").is_file() else b""
    packed = [b"scripts/player/helper.gd", Path(sp.GAME_ART).name.encode(), Path(sp.CONTROL_IMAGE).name.encode()]
    leaked = [Path(r).name.encode() for r in sp.IGNORED_IMAGES] + [b"decoy_ignored.gd", b"decoy_dot.gd", b"scripts/ci/"]
    c.expect(name, "the pack contains the game code, the game art and the control image, and no ignored image, no ignored decoy script and nothing of scripts/ci",
             bool(pck) and all(x in pck for x in packed) and not any(x in pck for x in leaked),
             f"pck={len(pck)} bytes missing={[x for x in packed if x not in pck]} leaked={[x for x in leaked if x in pck]}")
    rc, checks, _ = c.smoke(name, out)
    c.expect(name, "browser smoke (strict): the game code under scripts/ loads at runtime", rc == 0 and checks.get("no-fatal-console") == "pass", f"rc={rc} checks={checks}")
    # The tooling folder is skipped by RULE, not only by its .gdignore (stage 1 commits no .gdignore; the stage-2 project adds it).
    (p / "scripts" / "ci" / ".gdignore").unlink()
    rc, text = c.ci("validate-resources", p, tool=tool)
    counts, skipped = walker_result(text)
    c.expect(name, "validate-resources never walks scripts/ci, even without its .gdignore (an invalid script there is not loaded)",
             rc == 0 and counts == (sp.GAME_SCRIPT_COUNT, 1) and "res://scripts/ci" in skipped, f"rc={rc} counts={counts} skipped={skipped}")


def static_case(case: str, code: str) -> Callable[[Ctx], None]:
    def run(c: Ctx) -> None:
        p = c.build_fixture(case)
        rc, text = c.py("validate_godot_project.py", "--project", str(p), "--repo-root", str(c.work))
        c.expect(case, f"validate-project must exit 1 with {code}", rc == 1 and code in text, f"rc={rc}")
    return run


def case_selftest_fixture_refused(c: Ctx) -> None:
    """Defence in depth: a generated fixture that ever reached the repository would fail PRJ014 (the allow flag exists only here)."""
    p = c.build_fixture("good")
    env = {k: v for k, v in c.env.items() if k != ALLOW_SELFTEST_ENV}
    rc, text = c.run([sys.executable, str(HERE / "validate_godot_project.py"), "--project", str(p), "--repo-root", str(c.work)], env=env)
    c.expect("selftest_fixture_refused", "validate-project without the allow flag must exit 1 with PRJ014", rc == 1 and "PRJ014" in text, f"rc={rc}")


def case_parse_error(c: Ctx) -> None:
    p = c.build_fixture("parse_error")  # orphan broken.gd: Godot's import neither sees nor reports it
    rc, _ = c.ci("import", p)
    rc2, text = c.ci("validate-resources", p)
    c.expect("parse_error", "import alone passes (Godot cannot see the orphan script); validate-resources must fail and name broken.gd", rc == 0 and rc2 == 1 and "broken.gd" in text, f"import_rc={rc} validate_rc={rc2}")


def case_parse_error_referenced(c: Ctx) -> None:
    p = c.build_fixture("parse_error_referenced")  # Godot exits 0 here; only the log scan can catch it
    rc, text = c.ci("import", p)
    c.expect("parse_error_referenced", "import must fail on 'Parse Error' although Godot exits 0", rc == 1 and "Parse Error" in text, f"rc={rc}")


def browser_negative(case: str, must_fail: str, evidence: str, must_pass: Tuple[str, ...]) -> Callable[[Ctx], None]:
    """The named check must fail BECAUSE OF the injected fault (its recorded detail matches `evidence`), not for another reason."""
    def run(c: Ctx) -> None:
        p = c.build_fixture(case)
        rc, _ = c.ci("import", p)
        ok, out = c.export_selftest(p)
        if not (rc == 0 and ok):
            c.expect(case, "build the broken fixture (must succeed so the browser is what catches it)", False, f"import_rc={rc} export_ok={ok}")
            return
        rc, checks, _ = c.smoke(case, out)
        detail = c.details.get(must_fail, "")
        c.expect(case, f"browser smoke must fail at {must_fail} because of the injected fault, while {', '.join(must_pass)} still pass",
                 rc == 1 and checks.get(must_fail) == "fail" and re.search(evidence, detail) is not None and all(checks.get(n) == "pass" for n in must_pass),
                 f"rc={rc} checks={checks} detail={detail[:160]}")
    return run


def case_threads_enabled_export(c: Ctx) -> None:
    """A threaded export that slips past the static validator must still be rejected by finalize-export AND by the browser."""
    p = c.build_fixture("threads_enabled")
    c.ci("import", p)
    out = c.work / "threads_enabled-export"
    rc, text = c.ci("export", p, "--out", str(out))
    c.expect("threads_enabled_export", "export step refuses a threaded export (structural check) after the engine wrote it", rc == 1 and "THREADED export" in text and (out / "index.html").is_file(), f"rc={rc}")
    rc, text = c.ci("finalize-export", p, "--out", str(out), "--kind", "selftest", "--commit-sha", SELFTEST_SHA)
    c.expect("threads_enabled_export", "finalize-export must refuse: THREADED export", rc == 1 and "THREADED export" in text, f"rc={rc}")
    if not (out / "index.html").is_file():
        return
    # Forge the identity card ONLY here, so the browser-level backstop is exercised independently of the structural check.
    export_tools.write_build_info(out, kind="selftest", env={"GITHUB_SHA": SELFTEST_SHA}, godot_version=pinlib.load()["GODOT_VERSION"],
                                  godot_version_string="forged-for-selftest", project_dir=".", project_name="selftest")
    rc, checks, _ = c.smoke("threads_enabled_export", out)
    c.expect("threads_enabled_export", "browser smoke must fail at engine-start with the missing Cross-Origin Isolation notice (no COOP/COEP, exactly like Pages)",
             rc == 1 and checks.get("engine-start") == "fail" and "Cross-Origin Isolation" in c.details.get("engine-start", ""), f"rc={rc} checks={checks} detail={c.details.get('engine-start', '')[:160]}")


CASES: Dict[str, Callable[[Ctx], None]] = {
    "good": case_good,
    "forward_plus_base": case_forward_plus_base,
    "repo_shaped_layout": case_repo_shaped_layout,
    "threads_enabled": static_case("threads_enabled", "EXP005"),
    "missing_main_scene": static_case("missing_main_scene", "PRJ004"),
    "no_main_scene": static_case("no_main_scene", "PRJ003"),
    "web_renderer_override": static_case("web_renderer_override", "PRJ006"),
    "gdignore_scripts": static_case("gdignore_scripts", "PRJ013"),
    "selftest_fixture_refused": case_selftest_fixture_refused,
    "parse_error": case_parse_error,
    "parse_error_referenced": case_parse_error_referenced,
    "threads_enabled_export": case_threads_enabled_export,
    **{name: browser_negative(name, *spec) for name, spec in BROWSER_NEGATIVES.items()},
}


def completeness_problems(results: Sequence[dict], selected: Sequence[str], expected: Dict[str, int] = EXPECTED_COUNTS) -> List[str]:
    """Every selected case must have recorded exactly its expected number of expectations (no more, no fewer)."""
    problems = []
    for name in selected:
        got = sum(1 for r in results if r["case"] == name)
        if got != expected[name]:
            problems.append(f"{name}: recorded {got} expectation(s), expected {expected[name]}")
    return problems


def inside(child: Path, parent: Path) -> bool:
    return child == parent or parent in child.parents


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--godot-dir", type=Path, required=True, help="directory created by install_godot.py (with --with-threaded-templates)")
    ap.add_argument("--work-dir", type=Path, required=True, help="scratch directory for the throwaway projects: must be OUTSIDE the repository and empty or created by an earlier self-test run")
    ap.add_argument("--evidence-dir", type=Path, required=True)
    ap.add_argument("--cases", help="comma-separated case ids (local debugging only: the run is labelled PARTIAL)")
    args = ap.parse_args(argv)
    work, evidence = args.work_dir.resolve(), args.evidence_dir.resolve()
    if inside(work, REPO_ROOT) or inside(evidence, REPO_ROOT):
        annotate("error", "--work-dir and --evidence-dir must be outside the repository: a generated Godot project must never end up in the repo tree.", title="Self-test")
        return 2
    partial = args.cases is not None
    names = [n.strip() for n in args.cases.split(",") if n.strip()] if partial else list(ALL_CASES)
    unknown = [n for n in names if n not in CASES]
    if unknown or not names:
        print(f"unknown or empty case list {unknown or names}; known: {sorted(CASES)}", file=sys.stderr)
        return 2
    try:
        work = prepare_owned_dir(work)  # wipes only a directory an earlier run marked; never a home, checkout or foreign directory
    except UnsafePath as e:
        annotate("error", str(e), title="Self-test")
        return 2
    evidence.mkdir(parents=True, exist_ok=True)
    (evidence / "NOT-THE-GAME.txt").write_text("These files come from the pipeline SELF-TEST. They verify the CI tooling with generated throwaway projects. They are not the game and were never deployed.\n", encoding="utf-8")
    c = Ctx(args, pinlib.load())
    started = time.time()
    for name in names:
        print(f"[selftest] ===== case {name}", flush=True)
        try:
            CASES[name](c)
        except Exception as e:  # a crash inside a case is a failed expectation, never a pass
            c.expect(name, "case crashed", False, f"{type(e).__name__}: {e}")
    for problem in completeness_problems(c.results, names):
        c.expect("harness", "completeness", False, problem)
    bad = [r for r in c.results if not r["ok"]]
    rows = "".join(f"| {r['case']} | {r['step']} | {'PASS' if r['ok'] else 'FAIL'} | {r['detail'][:120].replace('|', '/')} |\n" for r in c.results)
    scope = f"PARTIAL RUN ({len(names)} of {len(ALL_CASES)} cases; not a valid verification)" if partial else f"all {len(names)} cases ran"
    summary = (f"## Pipeline self-test (tooling verification, NOT the game, nothing deployed): {'PASS' if not bad else 'FAIL'}\n\n"
               f"{scope}; {len(c.results) - len(bad)}/{len(c.results)} expectations met in {time.time() - started:.0f}s.\n\n| Case | Step | Result | Detail |\n| --- | --- | --- | --- |\n{rows}")
    (evidence / "summary.md").write_text(summary, encoding="utf-8", newline="\n")
    (evidence / "selftest-results.json").write_text(json.dumps(c.results, indent=1), encoding="utf-8", newline="\n")
    write_summary(summary)
    print(summary.split("\n", 2)[0])
    print(scope + f"; {len(c.results) - len(bad)}/{len(c.results)} expectations met")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
