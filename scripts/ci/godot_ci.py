#!/usr/bin/env python3
"""Run the Godot pipeline steps exactly as the workflows (and a Windows developer) do (stdlib only).

  godot_ci.py import             --project P [--godot G] [--log-dir L]
  godot_ci.py validate-resources --project P ...
  godot_ci.py tests              --project P ...
  godot_ci.py export             --project P --out DIR ...        (Web preset "Web", DEBUG template, single-threaded)
  godot_ci.py finalize-export    --project P --out DIR --kind game|selftest
  godot_ci.py check-export       --dir DIR [--kind game] [--expect-sha SHA]

Godot exits 0 on many real errors, so every Godot step ALSO scans its output (godot_log.scan) and fails on engine
ERROR / SCRIPT ERROR lines. The Web export uses the DEBUG template on purpose: release templates silently swallow
GDScript runtime errors (verified on 4.7.2), which would make the browser smoke test blind to them.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, Optional

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import export_tools  # noqa: E402
import godot_log  # noqa: E402
import godot_walker  # noqa: E402
import pins as pinlib  # noqa: E402
from ci_common import MAX_LOG_BYTES, annotate, group, run_logged, sanitize, write_summary  # noqa: E402

PRESET = "Web"
ALLOWLIST = HERE / "godot-log-allowlist.txt"
TIMEOUTS = {"import": 900, "validate": 600, "tests": 900, "export": 900}


def godot_bin(args: argparse.Namespace) -> str:
    path = args.godot or os.environ.get("GODOT_BIN")
    if not path or not Path(path).is_file():
        raise SystemExit("ERROR: Godot binary not found. Pass --godot or set GODOT_BIN (install: scripts/ci/install_godot.py install ...).")
    return path


def project_dir(args: argparse.Namespace) -> Path:
    p = Path(args.project).resolve()
    if not (p / "project.godot").is_file():
        raise SystemExit(f"ERROR: {p} does not contain project.godot")
    return p


def run_godot_step(name: str, args: argparse.Namespace, godot_args: List[str], timeout: int, *, allow_exit_codes=(0,), extra_error_re: Optional[re.Pattern] = None) -> godot_log.ScanResult:
    """Run Godot, log it, scan it. Exits the process with 1 on a nonzero exit, a timeout or any engine error line."""
    log_dir = Path(args.log_dir)
    cmd = [godot_bin(args), *godot_args]
    with group(f"godot {name}: {' '.join(cmd[1:])}"):
        res = run_logged(cmd, log_path=log_dir / f"{name}.log", timeout=timeout)
        print(sanitize(res.text[-6000:], 6000))
    scan = godot_log.scan(res.text, godot_log.load_allowlist(ALLOWLIST))
    if extra_error_re is not None:  # step-specific failure lines (for example VALIDATE_RESOURCES_FAIL)
        scan.errors.extend(ln for ln in res.text.splitlines() if extra_error_re.match(ln))
    problems = []
    if res.timed_out:
        problems.append(f"timed out after {timeout}s")
    elif res.overflow:
        problems.append(f"printed more than {MAX_LOG_BYTES // 2**20} MiB (runaway output); the process was killed")
    elif res.returncode not in allow_exit_codes:
        problems.append(f"exit code {res.returncode}")
    if scan.errors:
        problems.append(f"{len(scan.errors)} engine error line(s)")
    rows = f"| Exit code | {res.returncode} |\n| Duration | {res.seconds:.1f}s |\n| Engine errors | {len(scan.errors)} |\n| Engine warnings | {len(scan.warnings)} |\n"
    first = "".join(f"- `{sanitize(e, 200)}`\n" for e in scan.errors[:8])
    write_summary(f"## Godot {name}: {'FAIL' if problems else 'PASS'}\n\n| | |\n| --- | --- |\n{rows}\n{first}")
    for e in scan.errors[:20]:
        annotate("error", e, title=f"Godot {name}")
    for w in scan.warnings[:10]:
        annotate("warning", w, title=f"Godot {name}")
    if problems:
        annotate("error", f"Godot {name} failed: {'; '.join(problems)}. Full log: {log_dir / (name + '.log')}", title=f"Godot {name}")
        sys.exit(1)
    return scan


def untracked_sidecars(project: Path) -> List[str]:
    """*.uid / *.import files that import created but are not tracked (they should be committed). Best effort."""
    try:
        out = subprocess.run(["git", "-C", str(project), "status", "--porcelain", "--untracked-files=all", "--", "."],
                             capture_output=True, text=True, timeout=60).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    return [ln[3:] for ln in out.splitlines() if ln.startswith("??") and ln.rstrip().endswith((".uid", ".import"))]


def cmd_import(args: argparse.Namespace) -> int:
    project = project_dir(args)
    run_godot_step("import", args, ["--headless", "--path", str(project), "--import"], TIMEOUTS["import"])
    stray = untracked_sidecars(project)
    if stray:
        annotate("warning", f"Import created {len(stray)} untracked sidecar file(s) (*.uid / *.import), for example {stray[0]}. Commit them: Godot 4.4+ expects .uid files in version control and .import files keep import settings stable.", title="Uncommitted Godot sidecar files")
    return 0


def cmd_validate_resources(args: argparse.Namespace) -> int:
    """Run the headless walker (godot_walker.py) against the project. The script is written to a temporary folder OUTSIDE
    the project, so no .gd file of the pipeline is committed and nothing is ever written into res://."""
    project = project_dir(args)
    with tempfile.TemporaryDirectory(prefix="shinobi-walker-") as tmp:
        walker = godot_walker.write_walker(Path(tmp), project)  # ValueError if TMPDIR points into the project
        scan = run_godot_step("validate-resources", args, ["--headless", "--path", str(project), "--script", str(walker)], TIMEOUTS["validate"], extra_error_re=re.compile(r"^VALIDATE_RESOURCES_FAIL: "))
    log = (Path(args.log_dir) / "validate-resources.log").read_text(encoding="utf-8")
    m = re.search(r"^VALIDATE_RESOURCES: scripts=(\d+) scenes=(\d+) resources=(\d+) failures=(\d+)$", log, re.M)
    if not m:
        annotate("error", "the resource walker did not report a summary line (did Godot crash?)", title="Godot validate-resources")
        return 1
    scripts, scenes, resources, failures = map(int, m.groups())
    print(f"validated {scripts} scripts, {scenes} scenes, {resources} resources, {failures} failures")
    skipped = re.search(r"^VALIDATE_RESOURCES_SKIPPED: (.*)$", log, re.M)
    if skipped:  # folders that were deliberately not walked (.gdignore, dot folders, node_modules, exports, scripts/ci)
        print(f"not walked: {sanitize(skipped.group(1), 600) or '(none)'}")
    return 0 if failures == 0 and scan.ok else 1


def detect_test_frameworks(project: Path) -> List[str]:
    found = []
    if (project / "addons" / "gut" / "gut_cmdln.gd").is_file():
        found.append("gut")
    if (project / "addons" / "gdUnit4" / "bin" / "GdUnitCmdTool.gd").is_file():
        found.append("gdunit4")
    return found


def test_command(framework: str, project: Path) -> Optional[List[str]]:
    base = ["--headless", "--path", str(project)]
    tests_dir = next((d for d in ("tests", "test") if (project / d).is_dir()), None)
    if framework == "gut":
        if (project / ".gutconfig.json").is_file():
            return base + ["-s", "res://addons/gut/gut_cmdln.gd", "-gexit"]
        return base + ["-s", "res://addons/gut/gut_cmdln.gd", f"-gdir=res://{tests_dir}", "-ginclude_subdirs", "-gexit"] if tests_dir else None
    if framework == "gdunit4":
        return base + ["-s", "-d", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd", "--add", f"res://{tests_dir}", "--ignoreHeadlessMode"] if tests_dir else None
    raise ValueError(framework)


def cmd_tests(args: argparse.Namespace) -> int:
    project = project_dir(args)
    frameworks = detect_test_frameworks(project)
    if not frameworks:
        annotate("warning", "No GDScript test framework found (addons/gut or addons/gdUnit4). Gameplay logic is NOT unit-tested by CI. Recommended: GUT (vendor addons/gut and add tests under tests/).", title="No GDScript tests")
        write_summary("## GDScript tests: NONE FOUND (warning)\n\nNo GUT or gdUnit4 addon in the project; nothing was run.\n")
        return 0
    status = 0
    for fw in frameworks:
        godot_args = test_command(fw, project)
        if godot_args is None:
            annotate("warning", f"{fw} is installed but no tests/ or test/ directory (or .gutconfig.json) exists; no tests ran.", title="No GDScript tests")
            continue
        exit_ok = (0, 101) if fw == "gdunit4" else (0,)  # gdUnit4: 101 = passed with warnings
        scan = run_godot_step(f"tests-{fw}", args, godot_args, TIMEOUTS["tests"], allow_exit_codes=exit_ok)
        log = (Path(args.log_dir) / f"tests-{fw}.log").read_text(encoding="utf-8")
        if fw == "gut":
            gut_errors = [ln for ln in log.splitlines() if ln.startswith("[GUT ERROR]")]
            hard = [ln for ln in gut_errors if "Nothing was run" not in ln]
            if hard:
                annotate("error", "; ".join(hard[:3]), title="GUT")
                status = 1
            elif gut_errors:
                annotate("warning", "GUT ran 0 tests (Nothing was run).", title="No GDScript tests")
        if not scan.ok:
            status = 1
    return status


def report_findings(findings: List[export_tools.Finding], title: str) -> bool:
    ok = True
    for f in findings:
        annotate("error" if f.level == "error" else "warning", f.message, title=f"{title} {f.code}")
        ok = ok and f.level != "error"
    return ok


def cmd_export(args: argparse.Namespace) -> int:
    project = project_dir(args)
    out = Path(args.out).resolve()
    if out == project or project in out.parents:
        annotate("error", f"--out {out} is inside the project directory; Godot would import-scan the export. Use a directory outside the project.", title="Godot export")
        return 1
    if out.exists() and any(out.iterdir()):
        annotate("error", f"--out {out} is not empty; use a fresh directory.", title="Godot export")
        return 1
    out.mkdir(parents=True, exist_ok=True)  # the engine refuses to export into a missing folder
    run_godot_step("export", args, ["--headless", "--path", str(project), "--export-debug", PRESET, str(out / "index.html")], TIMEOUTS["export"])
    return 0 if report_findings([f for f in export_tools.check_export_dir(out)], "Web export") else 1


def project_name(project: Path) -> str:
    import godot_cfg
    try:
        sections = godot_cfg.parse_config((project / "project.godot").read_text(encoding="utf-8"))
        return godot_cfg.as_string(sections.get("application", {}).get("config/name")) or "unnamed"
    except (OSError, godot_cfg.ConfigError):
        return "unreadable"


def cmd_finalize_export(args: argparse.Namespace) -> int:
    project, out = project_dir(args), Path(args.out).resolve()
    findings = export_tools.check_export_dir(out)
    if not report_findings(findings, "Web export"):
        return 1
    env = dict(os.environ)
    if args.commit_sha is not None:  # an empty --commit-sha is a usage error, not "fall back to the environment"
        try:
            env["GITHUB_SHA"] = export_tools.require_sha40(args.commit_sha, "--commit-sha")
        except ValueError as e:
            annotate("error", str(e), title="build-info usage")
            return 2
    elif not env.get("GITHUB_SHA"):
        try:
            env["GITHUB_SHA"] = subprocess.run(["git", "-C", str(project), "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            annotate("error", "GITHUB_SHA is not set and git could not determine HEAD; pass --commit-sha.", title="build-info")
            return 1
    version = pinlib.load()["GODOT_VERSION"]
    version_string = env.get("GODOT_VERSION_STRING") or run_logged([godot_bin(args), "--version"], timeout=60).text.strip().splitlines()[-1]
    try:
        repo_root = Path(__file__).resolve().parents[2]
        rel = os.path.relpath(project, repo_root).replace("\\", "/") if repo_root in project.parents or repo_root == project else str(project)
        export_tools.write_build_info(out, kind=args.kind, env=env, godot_version=version, godot_version_string=version_string,
                                      project_dir=rel, project_name=project_name(project))
    except ValueError as e:
        annotate("error", str(e), title="build-info")
        return 1
    problems = export_tools.check_build_info(out, kind=args.kind, expect_sha=env["GITHUB_SHA"])
    if not report_findings(problems, "build-info"):
        return 1
    total = sum(p.stat().st_size for p in out.iterdir() if p.is_file())
    write_summary(f"## Web export: PASS\n\n| | |\n| --- | --- |\n| Kind | `{args.kind}` |\n| Commit | `{env['GITHUB_SHA']}` |\n| Engine | `{sanitize(version_string, 80)}` |\n| Template | debug, single-threaded, Compatibility |\n| Files | {len(list(out.iterdir()))} ({total // 2**20} MiB) |\n")
    print(f"export OK: {out} ({total // 2**20} MiB), build-info.json written for commit {env['GITHUB_SHA']}")
    return 0


def cmd_check_export(args: argparse.Namespace) -> int:
    d = Path(args.dir).resolve()
    try:  # --expect-sha is optional, but when it is given an empty or malformed value must not skip the check
        findings = export_tools.check_export_dir(d) + export_tools.check_build_info(d, kind=args.kind, expect_sha=args.expect_sha)
    except ValueError as e:
        annotate("error", str(e), title="export check usage")
        return 2
    ok = report_findings(findings, "export check")
    print("export check:", "OK" if ok else "FAILED", f"({d})")
    return 0 if ok else 1


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(p: argparse.ArgumentParser, project: bool = True) -> None:
        if project:
            p.add_argument("--project", required=True)
        p.add_argument("--godot", help="path to the Godot binary (default: $GODOT_BIN)")
        p.add_argument("--log-dir", default="godot-ci-logs")

    for name, fn in (("import", cmd_import), ("validate-resources", cmd_validate_resources), ("tests", cmd_tests)):
        common(sub.add_parser(name))
        sub.choices[name].set_defaults(fn=fn)
    p = sub.add_parser("export")
    common(p)
    p.add_argument("--out", required=True)
    p.set_defaults(fn=cmd_export)
    p = sub.add_parser("finalize-export")
    common(p)
    p.add_argument("--out", required=True)
    p.add_argument("--kind", choices=export_tools.KINDS, required=True)
    p.add_argument("--commit-sha", help="override GITHUB_SHA (local runs and the self-test)")
    p.set_defaults(fn=cmd_finalize_export)
    p = sub.add_parser("check-export")
    p.add_argument("--dir", required=True)
    p.add_argument("--kind", choices=export_tools.KINDS)
    p.add_argument("--expect-sha")
    p.set_defaults(fn=cmd_check_export)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
