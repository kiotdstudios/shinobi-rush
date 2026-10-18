#!/usr/bin/env python3
"""Deployment preflight and the godot-ci-gate evaluation (stdlib only).

  pages_gate.py preflight --gh-exit-code N --json FILE --stderr FILE     (deploy job, before anything is uploaded)
  pages_gate.py gate                                                      (env NEEDS_JSON, EVENT_NAME, GIT_REF)

The gate never turns "skipped" into success by accident: with no project it passes ONLY because nothing exists to
validate, says so loudly, and requires every Godot job to have been skipped.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Mapping, NamedTuple, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ci_common import annotate, sanitize, write_summary  # noqa: E402

DOC = "docs/development/GODOT_CI_AND_DEPLOYMENT.md"
GODOT_JOBS = ("build", "smoke-predeploy", "deploy", "smoke-postdeploy")
STAGES = (
    ("build", "Headless import, project/preset validation, script+scene validation, tests, Web export"),
    ("smoke-predeploy", "Pre-deploy browser smoke test (local static server)"),
    ("deploy", "Deploy to GitHub Pages"),
    ("smoke-postdeploy", "Post-deploy live smoke test (real URL, commit SHA match)"),
)


class Pages(NamedTuple):
    ok: bool
    message: str


def evaluate_pages(gh_exit_code: int, payload: str, stderr: str, allow_custom_domain: bool) -> Pages:
    if gh_exit_code != 0:
        first = (stderr.strip().splitlines() or ["(no error output)"])[0]
        if "404" in stderr or "Not Found" in stderr:
            return Pages(False, "GitHub Pages is NOT enabled for this repository, so nothing can be deployed (NOT DEPLOYED). An administrator must enable it: "
                                "Settings > Pages > Build and deployment > Source: GitHub Actions. This workflow never enables Pages and never edits environments, rulesets, variables or protection rules. "
                                f"Steps: {DOC} ('Admin-only steps').")
        return Pages(False, f"Could not read the GitHub Pages configuration (gh api exit {gh_exit_code}: {first}). The deploy job needs pages: write.")
    try:
        data = json.loads(payload)
    except ValueError:
        return Pages(False, "The Pages API returned something that is not JSON; refusing to deploy.")
    build_type = data.get("build_type")
    if build_type != "workflow":
        return Pages(False, f"Pages is configured with build_type={build_type!r} (deploy from a branch). Refusing to deploy so existing site content is never overwritten. "
                            "Set Settings > Pages > Source to GitHub Actions if this repository should host the live test build.")
    if data.get("cname") and not allow_custom_domain:
        return Pages(False, f"Pages has a custom domain ({data.get('cname')}), which suggests a production site. Refusing to deploy the live TEST build over it. "
                            "If this is intended, set the repository variable PAGES_ALLOW_CUSTOM_DOMAIN=true.")
    return Pages(True, f"Pages is enabled for GitHub Actions deployments; GitHub reports the site URL {data.get('html_url')} (informational; the verified URL is the page_url output of deploy-pages).")


class Gate(NamedTuple):
    ok: bool
    headline: str
    rows: List[tuple]  # (stage, result label)
    problems: List[str]


def result_of(needs: Mapping[str, Mapping[str, object]], job: str) -> str:
    return str((needs.get(job) or {}).get("result", "missing"))


def evaluate_gate(needs: Mapping[str, Mapping[str, object]], event_name: str, git_ref: str) -> Gate:
    problems: List[str] = []
    detect = result_of(needs, "detect")
    if detect != "success":
        return Gate(False, "FAILED: project detection did not succeed", [("Godot project", f"detect job result: {detect}")],
                    [f"The 'Detect Godot project' job result was {detect!r} (invalid GODOT_PROJECT_DIR, several projects without an override, or a pin/workflow hygiene violation)."])
    found = str(((needs.get("detect") or {}).get("outputs") or {}).get("project_found", ""))
    deploy_expected = event_name in ("push", "workflow_dispatch") and git_ref == "refs/heads/main"
    if found == "false":
        ran = [j for j in GODOT_JOBS if result_of(needs, j) != "skipped"]
        if ran:
            return Gate(False, "FAILED: Godot jobs ran although no project was found", [], [f"{j} result: {result_of(needs, j)}" for j in ran])
        rows = [("Godot project", "NOT FOUND (no project.godot in the repository)")] + [(label, "NOT RUN") for _, label in STAGES]
        rows[-2] = (STAGES[2][1], "NOT DEPLOYED")
        return Gate(True, "NOT VALIDATED, NOT DEPLOYED: no Godot project found", rows, [])
    if found != "true":
        return Gate(False, "FAILED: the detect job produced no usable project_found output", [], [f"project_found={found!r}"])
    required = ["build", "smoke-predeploy"] + (["deploy", "smoke-postdeploy"] if deploy_expected else [])
    rows = [("Godot project", "FOUND")]
    for job, label in STAGES:
        res = result_of(needs, job)
        if job in required:
            rows.append((label, "PASS" if res == "success" else f"FAIL ({res})"))
            if res != "success":
                problems.append(f"{job}: {res}")
        else:
            rows.append((label, "not applicable (only pushes to main and dispatches from main deploy)" if res == "skipped" else f"UNEXPECTED ({res})"))
            if res != "skipped":
                problems.append(f"{job} should have been skipped but was {res}")
    if problems:
        return Gate(False, "FAILED: " + "; ".join(problems), rows, problems)
    return Gate(True, "VALIDATED and DEPLOYED" if deploy_expected else "VALIDATED (not deployed: only main deploys)", rows, [])


def render_summary(g: Gate) -> str:
    lines = [f"## Godot CI gate: {'PASS' if g.ok else 'FAIL'}", "", f"**{g.headline}**", "", "| Stage | Result |", "| --- | --- |"]
    lines += [f"| {a} | {sanitize(b, 200)} |" for a, b in g.rows]
    if "NOT VALIDATED" in g.headline:
        lines += ["", "This check is green only because there is nothing to validate. It is NOT evidence that the game builds, passes tests, is deployed, or starts in a browser. "
                      f"What is needed: docs/development/GODOT_PROJECT_HANDOFF.md."]
    return "\n".join(lines) + "\n"


def cmd_preflight(args: argparse.Namespace) -> int:
    payload = Path(args.json).read_text(encoding="utf-8") if Path(args.json).is_file() else ""
    stderr = Path(args.stderr).read_text(encoding="utf-8") if Path(args.stderr).is_file() else ""
    res = evaluate_pages(args.gh_exit_code, payload, stderr, os.environ.get("PAGES_ALLOW_CUSTOM_DOMAIN", "").lower() == "true")
    annotate("notice" if res.ok else "error", res.message, title="GitHub Pages preflight")
    write_summary(f"## Pages preflight: {'OK' if res.ok else 'FAILED (NOT DEPLOYED)'}\n\n{sanitize(res.message, 800)}\n")
    return 0 if res.ok else 1


def cmd_gate(_: argparse.Namespace) -> int:
    try:
        needs = json.loads(os.environ["NEEDS_JSON"])
    except (KeyError, ValueError) as e:
        annotate("error", f"NEEDS_JSON is missing or invalid: {e}", title="godot-ci-gate")
        return 1
    g = evaluate_gate(needs, os.environ.get("EVENT_NAME", ""), os.environ.get("GIT_REF", ""))
    write_summary(render_summary(g))
    print(g.headline)
    if g.ok and "NOT VALIDATED" in g.headline:
        annotate("warning", "NOT VALIDATED, NOT DEPLOYED: no Godot project exists, so no Godot check ran. This gate is green only because there is nothing to validate.", title="godot-ci-gate")
    elif not g.ok:
        annotate("error", g.headline, title="godot-ci-gate")
    return 0 if g.ok else 1


def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    pf = sub.add_parser("preflight")
    pf.add_argument("--gh-exit-code", type=int, required=True)
    pf.add_argument("--json", required=True)
    pf.add_argument("--stderr", required=True)
    pf.set_defaults(fn=cmd_preflight)
    sub.add_parser("gate").set_defaults(fn=cmd_gate)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
