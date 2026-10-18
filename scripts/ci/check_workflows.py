#!/usr/bin/env python3
"""Mechanical hygiene checks for the CI definition itself (stdlib only; deliberately NOT a YAML parser).

Understands only this repository's workflow style (2-space block mappings) and fails closed on anything else.
  python3 scripts/ci/check_workflows.py            check everything
  python3 scripts/ci/check_workflows.py --write    also rewrite <!--pin:KEY-->..<!--/pin--> markers in the docs

Rules (code: meaning)
  PIN001 pin file invalid | PIN002 Playwright pin differs from package.json / package-lock.json | DOC001 doc pin marker stale
  WF001 BOM or CR (CR only checked in CI, where checkout == blobs) | WF002 no top-level permissions | WF003 write permission outside the deploy job
  WF004 action not pinned to a full commit SHA with a '# vX.Y.Z' comment | WF005 runs-on differs from RUNNER_IMAGE | WF006 forbidden trigger
  WF007 secrets used | WF008 job without timeout-minutes | WF009 checkout without persist-credentials: false
  WF010 untrusted expression | WF011 workflow_dispatch inputs | WF012 paths filter on a workflow that owns a required check
  WF013 required check job renamed/missing | WF014 deploy job contract violated (permissions, environment, concurrency, exact if/needs)
  WF015 Pages/OIDC/environment privileges outside the deploy job | WF016 a workflow runs a PARTIAL self-test (--cases)
  WF017 a run step calls scripts/ci/*.py or smoke.mjs with a missing script or a flag the script does not define
  WF018 continue-on-error or '|| true' (a step must never swallow its own failure)
  WF019 a workflow mentions the self-test allow flag (it switches off the PRJ014 self-test-fixture guard; only selftest.py may set it)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, NamedTuple, Optional, Tuple

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import pins as pinlib  # noqa: E402
from ci_common import ALLOW_SELFTEST_ENV, annotate  # noqa: E402

REQUIRED_CHECK_JOBS = {"repository-checks.yml": "validate-orders-and-project", "godot-ci.yml": "godot-ci-gate"}
DEPLOY_CONTRACT = ("godot-ci.yml", "deploy", {"contents": "read", "pages": "write", "id-token": "write"})
# The deployment gate is spelled out, not implied: every upstream result is named, so adding always()/!cancelled()/failure()
# (a common edit) or dropping a gate cannot silently let a failed or skipped build reach Pages. Change these constants in the
# same pull request as the workflow, with review.
DEPLOY_IF = ("needs.detect.outputs.project_found == 'true' && needs.build.result == 'success' && needs.smoke-predeploy.result == 'success' && "
             "github.ref == 'refs/heads/main' && (github.event_name == 'push' || github.event_name == 'workflow_dispatch')")
DEPLOY_NEEDS = {"detect", "build", "smoke-predeploy"}
POSTDEPLOY_CONTRACT = ("godot-ci.yml", "smoke-postdeploy", "needs.detect.outputs.project_found == 'true' && needs.deploy.result == 'success'", {"detect", "deploy"})
PRIVILEGED = re.compile(r"^\s*(?:-\s+)?(?:environment|pages|id-token):|actions/(?:configure-pages|upload-pages-artifact|deploy-pages)@")
SCRIPT_CALL = re.compile(r"(?:^|\s)python3\s+scripts/ci/([A-Za-z0-9_]+\.py)\b(.*)$")
SMOKE_CALL = re.compile(r"(?:^|\s)node\s+smoke\.mjs\b(.*)$")
SHELL_OPERATORS = re.compile(r"\s*(?:&&|\|\||[|;>])")
DOC_FILES = ("docs/development/GODOT_CI_AND_DEPLOYMENT.md", "docs/development/GODOT_PROJECT_HANDOFF.md")
UNTRUSTED = re.compile(r"\$\{\{[^}]*\b(github\.head_ref|github\.event\.(pull_request\.(title|body|head\.ref|head\.label)|head_commit\.message|commits|issue|comment|review|pages)|inputs\.|github\.event\.inputs)")
USES = re.compile(r"^(\s*)(?:-\s+)?uses:\s*(\S+)(?:\s+#\s*(.*?))?\s*$")
MARKER = re.compile(r"<!--pin:([A-Z0-9_]+)-->(.*?)<!--/pin-->")


class Problem(NamedTuple):
    path: str
    line: int
    code: str
    message: str


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix() if ROOT in p.parents else str(p)


def split_jobs(lines: List[str]) -> Dict[str, List[int]]:
    """job id -> [first line index, last line index) of its block, using 2-space indentation."""
    start = next((i for i, ln in enumerate(lines) if ln.rstrip() == "jobs:"), None)
    if start is None:
        return {}
    ids: List[tuple] = []
    for i in range(start + 1, len(lines)):
        if lines[i] and not lines[i].startswith((" ", "#")):
            break
        m = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", lines[i])
        if m:
            ids.append((m.group(1), i))
    end_of_jobs = next((i for i in range(start + 1, len(lines)) if lines[i] and not lines[i].startswith((" ", "#"))), len(lines))
    return {jid: [i, (ids[n + 1][1] if n + 1 < len(ids) else end_of_jobs)] for n, (jid, i) in enumerate(ids)}


def normalize_expr(value: str) -> str:
    """`${{ a  &&  b }}` -> `a && b` (whitespace collapsed) so job conditions can be compared exactly."""
    v = value.strip()
    m = re.fullmatch(r"\$\{\{(.*)\}\}", v, re.S)
    return " ".join((m.group(1) if m else v).split())


def job_value(block: List[str], key: str) -> Optional[str]:
    for ln in block:
        m = re.match(rf"^    {re.escape(key)}:\s*(.*?)\s*$", ln)
        if m:
            return m.group(1)
    return None


def name_set(value: Optional[str]) -> set:
    return {x.strip() for x in (value or "").strip("[]").split(",") if x.strip()}


def run_blocks(lines: List[str]) -> List[Tuple[int, List[str]]]:
    """(line number, logical command lines) for every `run:` value. Folded (>) blocks are joined into one command and
    backslash continuations are joined, so a command that spans several lines is checked as a whole."""
    out: List[Tuple[int, List[str]]] = []
    i = 0
    while i < len(lines):
        m = re.match(r"^(\s*(?:-\s+)?)run:\s*(.*?)\s*$", lines[i])
        if not m:
            i += 1
            continue
        col, rest, body, j = len(m.group(1)), m.group(2), [], i + 1
        if rest in ("|", "|-", "|+", ">", ">-", ">+"):
            while j < len(lines) and (not lines[j].strip() or len(lines[j]) - len(lines[j].lstrip()) > col):
                body.append(lines[j].strip())
                j += 1
            if rest.startswith(">"):
                body = [" ".join(b for b in body if b)]
        else:
            body = [rest]
        logical, cur = [], ""
        for b in body:
            if b.endswith("\\"):
                cur += b[:-1].rstrip() + " "
            else:
                logical.append(cur + b)
                cur = ""
        if cur:
            logical.append(cur.strip())
        out.append((i + 1, [x for x in logical if x and not x.startswith("#")]))
        i = j
    return out


def flags_of(command_tail: str) -> List[str]:
    tail = SHELL_OPERATORS.split(command_tail, maxsplit=1)[0]
    return re.findall(r"(?<=\s)(--[A-Za-z0-9][A-Za-z0-9-]*)", " " + tail)


def check_commands(lines: List[str], repo: Path, add) -> None:
    """WF017: a typo in a flag or script name would otherwise first fail in the first real run of a job that has never
    executed (the Godot jobs are skipped until a project exists)."""
    smoke_args = repo / "scripts" / "ci" / "smoke" / "lib" / "args.mjs"
    for line_no, commands in run_blocks(lines):
        for cmd in commands:
            m = SCRIPT_CALL.search(cmd)
            if m:
                script = repo / "scripts" / "ci" / m.group(1)
                if not script.is_file():
                    add(line_no, "WF017", f"scripts/ci/{m.group(1)} does not exist")
                    continue
                src = script.read_text(encoding="utf-8")
                for flag in flags_of(m.group(2)):
                    if f'"{flag}"' not in src and f"'{flag}'" not in src:
                        add(line_no, "WF017", f"{m.group(1)} defines no option {flag}")
                if m.group(1) == "selftest.py" and "--cases" in flags_of(m.group(2)):
                    add(line_no, "WF016", "the self-test must run all cases in CI; --cases makes a PARTIAL run that proves nothing")
            m = SMOKE_CALL.search(cmd)
            if m and smoke_args.is_file():
                src = smoke_args.read_text(encoding="utf-8")
                for flag in flags_of(m.group(1)):
                    name = flag[2:]
                    if not re.search(rf"""(?:['"]{re.escape(name)}['"]|\b{re.escape(name)}\b)\s*:""", src):
                        add(line_no, "WF017", f"smoke.mjs defines no option {flag}")


def block_permissions(lines: List[str], at: int, indent: int, stop: int) -> Optional[Dict[str, str]]:
    """Parse a `permissions:` mapping that starts at line `at` (indent spaces) into {scope: level}."""
    perms: Dict[str, str] = {}
    for i in range(at + 1, stop):
        m = re.match(rf"^{' ' * (indent + 2)}([a-z-]+):\s*(\S+)\s*$", lines[i])
        if m:
            perms[m.group(1)] = m.group(2)
        elif lines[i].strip() and not lines[i].startswith(" " * (indent + 2)):
            break
    return perms


def check_workflow(path: Path, pins: Dict[str, str], ci_mode: bool) -> List[Problem]:
    name, probs = path.name, []
    raw = path.read_bytes()
    text = raw.decode("utf-8")
    add = lambda line, code, msg: probs.append(Problem(rel(path), line, code, msg))  # noqa: E731
    if raw.startswith(b"\xef\xbb\xbf"):
        add(1, "WF001", "file starts with a BOM")
    if ci_mode and b"\r" in raw:
        add(1, "WF001", "file contains CR characters (must be LF)")
    lines = text.replace("\r\n", "\n").split("\n")
    code_lines = [(i, ln) for i, ln in enumerate(lines) if not ln.lstrip().startswith("#")]

    top = block_permissions(lines, next((i for i, ln in enumerate(lines) if ln.rstrip() == "permissions:"), -1), 0, len(lines)) if any(ln.rstrip() == "permissions:" for ln in lines) else None
    if top is None:
        add(1, "WF002", "no top-level permissions: block (default token permissions must be set explicitly)")
    elif top != {"contents": "read"}:
        add(1, "WF003", f"top-level permissions must be exactly 'contents: read', found {top}")

    for i, ln in code_lines:
        if re.search(r"\b(pull_request_target|workflow_run):", ln):
            add(i + 1, "WF006", "pull_request_target / workflow_run triggers are forbidden (they run with elevated tokens on untrusted code)")
        if re.match(r"^\s*(?:-\s+)?continue-on-error\s*:", ln) or re.search(r"\|\|\s*true\b", ln):
            add(i + 1, "WF018", "continue-on-error / '|| true' lets a failing step pass; no step in this pipeline may swallow a failure")
        if ALLOW_SELFTEST_ENV in ln:
            add(i + 1, "WF019", f"{ALLOW_SELFTEST_ENV} switches off the PRJ014 self-test-fixture guard; only selftest.py may set it, for its own child processes, never a workflow")
        if re.search(r"\$\{\{[^}]*\bsecrets\.", ln):
            add(i + 1, "WF007", "secrets are not used by this pipeline; add them only through a deliberate design change")
        if UNTRUSTED.search(ln):
            add(i + 1, "WF010", "untrusted expression (PR title/body/branch name/inputs); pass trusted values via env or avoid")
        m = USES.match(ln)
        if m:
            target, comment = m.group(2), m.group(3) or ""
            if target.startswith(("./", "docker://")) or not re.fullmatch(r"[\w.-]+/[\w./-]+@[0-9a-f]{40}", target):
                add(i + 1, "WF004", f"{target}: actions must be pinned to a 40-hex commit SHA (no tags, no local/docker actions)")
            elif not re.match(r"v\d+\.\d+\.\d+", comment):
                add(i + 1, "WF004", f"{target}: add a '# vX.Y.Z' comment naming the release the SHA belongs to")
            if target.startswith("actions/checkout@"):
                step_end = next((j for j in range(i + 1, len(lines)) if re.match(r"^\s*-\s", lines[j]) and (len(lines[j]) - len(lines[j].lstrip())) <= len(m.group(1)) + 2), len(lines))
                if not any(re.match(r"^\s+persist-credentials:\s*false\s*$", lines[j]) for j in range(i, step_end)):
                    add(i + 1, "WF009", "actions/checkout must set 'persist-credentials: false'")
        if re.match(r"^\s+inputs:\s*$", ln) and "workflow_dispatch" in text:
            add(i + 1, "WF011", "workflow_dispatch inputs are not used by this pipeline; add them only through a deliberate design change")
        if re.match(r"^\s+(paths|paths-ignore):\s*$", ln) and name in REQUIRED_CHECK_JOBS:
            add(i + 1, "WF012", f"{name} owns the required check '{REQUIRED_CHECK_JOBS[name]}': a workflow-level paths filter would leave it Pending forever when skipped")

    jobs = split_jobs(lines)
    if name in REQUIRED_CHECK_JOBS and REQUIRED_CHECK_JOBS[name] not in jobs:
        add(1, "WF013", f"job id '{REQUIRED_CHECK_JOBS[name]}' is missing from {name}: it is (or will be) a required status check; renaming it blocks merging")
    for jid, (a, b) in jobs.items():
        block = lines[a:b]
        if not any(re.match(r"^    timeout-minutes:\s*\d+\s*$", ln) for ln in block):
            add(a + 1, "WF008", f"job '{jid}' has no timeout-minutes")
        ro = next((re.match(r"^    runs-on:\s*(\S+)\s*$", ln) for ln in block if re.match(r"^    runs-on:", ln)), None)
        if not ro or ro.group(1) != pins["RUNNER_IMAGE"]:
            add(a + 1, "WF005", f"job '{jid}' must use runs-on: {pins['RUNNER_IMAGE']} (found {ro.group(1) if ro else 'nothing'})")
        pi = next((k for k, ln in enumerate(block) if ln.rstrip() == "    permissions:"), None)
        jperms = block_permissions(block, pi, 4, len(block)) if pi is not None else {}
        is_deploy = (name, jid) == DEPLOY_CONTRACT[:2]
        if is_deploy and jperms != DEPLOY_CONTRACT[2]:
            add(a + 1, "WF014", f"deploy job permissions must be exactly {DEPLOY_CONTRACT[2]}, found {jperms}")
        if not is_deploy and any(v == "write" for v in jperms.values()):
            add(a + 1, "WF003", f"job '{jid}' must not request write permissions (only the deploy job may)")
        if is_deploy:
            joined = "\n".join(block)
            for needle, why in (("environment:", "environment: github-pages with a url output"), ("name: github-pages", "environment name github-pages"),
                                ("cancel-in-progress: false", "concurrency with cancel-in-progress: false"), ("refs/heads/main", "an if: restricting it to main")):
                if needle not in joined:
                    add(a + 1, "WF014", f"deploy job lacks {why}")
            if normalize_expr(job_value(block, "if") or "") != DEPLOY_IF:
                add(a + 1, "WF014", f"deploy job 'if' must be exactly: {DEPLOY_IF}  (found: {normalize_expr(job_value(block, 'if') or '') or 'nothing'}). Name every gate result; never use always(), !cancelled() or failure() here.")
            if name_set(job_value(block, "needs")) != DEPLOY_NEEDS:
                add(a + 1, "WF014", f"deploy job 'needs' must be exactly {sorted(DEPLOY_NEEDS)}, found {sorted(name_set(job_value(block, 'needs')))}")
        if (name, jid) == POSTDEPLOY_CONTRACT[:2]:
            if normalize_expr(job_value(block, "if") or "") != POSTDEPLOY_CONTRACT[2] or name_set(job_value(block, "needs")) != POSTDEPLOY_CONTRACT[3]:
                add(a + 1, "WF014", f"{jid} must have needs {sorted(POSTDEPLOY_CONTRACT[3])} and 'if' exactly: {POSTDEPLOY_CONTRACT[2]}")
        if not is_deploy:  # WF015: Pages/OIDC/environment privileges exist only in the deploy job
            for k, ln in enumerate(block):
                if PRIVILEGED.search(ln) and not ln.lstrip().startswith("#"):
                    add(a + k + 1, "WF015", f"job '{jid}' uses a Pages/OIDC/environment privilege ({ln.strip()}); only the deploy job of godot-ci.yml may")
    first_job = min((rng[0] for rng in jobs.values()), default=len(lines))
    for k, ln in enumerate(lines[:first_job]):
        if PRIVILEGED.search(ln) and not ln.lstrip().startswith("#"):
            add(k + 1, "WF015", f"workflow-level Pages/OIDC/environment privilege ({ln.strip()}); only the deploy job may have these")
    check_commands(lines, path.resolve().parents[2], add)
    return probs


def check_playwright_consistency(pins: Dict[str, str]) -> List[Problem]:
    want, probs = pins["PLAYWRIGHT_VERSION"], []
    smoke = HERE / "smoke"
    try:
        pkg = json.loads((smoke / "package.json").read_text(encoding="utf-8"))
        lock = json.loads((smoke / "package-lock.json").read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        return [Problem(rel(smoke), 1, "PIN002", f"cannot read package.json / package-lock.json: {e}")]
    got = {
        "package.json dependencies.playwright": (pkg.get("dependencies") or {}).get("playwright"),
        "package-lock.json root dependency": ((lock.get("packages") or {}).get("") or {}).get("dependencies", {}).get("playwright"),
        "package-lock.json node_modules/playwright": ((lock.get("packages") or {}).get("node_modules/playwright") or {}).get("version"),
        "package-lock.json node_modules/playwright-core": ((lock.get("packages") or {}).get("node_modules/playwright-core") or {}).get("version"),
    }
    for where, version in got.items():
        if version != want:
            probs.append(Problem(rel(smoke), 1, "PIN002", f"{where} is {version!r} but PLAYWRIGHT_VERSION pins {want!r} (exact versions only)"))
    return probs


def doc_values(pins: Dict[str, str]) -> Dict[str, str]:
    return {**pins, **pinlib.derived(pins)}


def check_docs(pins: Dict[str, str], write: bool) -> List[Problem]:
    probs, values = [], doc_values(pins)
    for relpath in DOC_FILES:
        path = ROOT / relpath
        if not path.is_file():
            probs.append(Problem(relpath, 1, "DOC001", "documentation file is missing"))
            continue
        text = path.read_text(encoding="utf-8")

        def fix(m: "re.Match[str]") -> str:
            key = m.group(1)
            return f"<!--pin:{key}-->`{values[key]}`<!--/pin-->" if key in values else m.group(0)

        for m in MARKER.finditer(text):
            key, inner = m.group(1), m.group(2)
            line = text.count("\n", 0, m.start()) + 1
            if key not in values:
                probs.append(Problem(relpath, line, "DOC001", f"unknown pin marker {key}"))
            elif inner != f"`{values[key]}`":
                probs.append(Problem(relpath, line, "DOC001", f"pin marker {key} says {inner} but the pin file says `{values[key]}` (run check_workflows.py --write)"))
        if write:
            new = MARKER.sub(fix, text)
            if new != text:
                path.write_text(new, encoding="utf-8", newline="\n")
                probs = [p for p in probs if p.path != relpath]
    return probs


def check_text_hygiene(ci_mode: bool) -> List[Problem]:
    probs = []
    for p in sorted(list((ROOT / "scripts" / "ci").rglob("*")) + [ROOT / ".gitattributes", ROOT / ".gitignore"]):
        if "node_modules" in p.parts or "__pycache__" in p.parts or not p.is_file() or p.suffix in (".png", ".pyc"):
            continue
        raw = p.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            probs.append(Problem(rel(p), 1, "WF001", "file starts with a BOM"))
        if ci_mode and b"\r" in raw:
            probs.append(Problem(rel(p), 1, "WF001", "file contains CR characters (must be LF)"))
    return probs


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--write", action="store_true", help="rewrite stale pin markers in the docs")
    ap.add_argument("--check-eol", choices=["auto", "always", "never"], default="auto", help="auto = only in GitHub Actions (checkout == blobs)")
    ap.add_argument("--root", type=Path, help="repository root (tests)")
    args = ap.parse_args(argv)
    global ROOT
    if args.root:
        ROOT = args.root.resolve()
    ci_mode = args.check_eol == "always" or (args.check_eol == "auto" and os.environ.get("GITHUB_ACTIONS") == "true")
    try:
        pins = pinlib.load(ROOT / "scripts" / "ci" / "godot-version.env")
    except pinlib.PinError as e:
        annotate("error", str(e), title="PIN001")
        return 1
    probs: List[Problem] = []
    for wf in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
        probs += check_workflow(wf, pins, ci_mode)
    probs += check_playwright_consistency(pins) + check_docs(pins, args.write) + check_text_hygiene(ci_mode)
    for p in probs:
        annotate("error", p.message, title=p.code, file=p.path, line=p.line)
    print(f"check_workflows: {'FAILED' if probs else 'OK'} - {len(probs)} problem(s)")
    return 1 if probs else 0


if __name__ == "__main__":
    sys.exit(main())
