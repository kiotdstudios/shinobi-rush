#!/usr/bin/env python3
"""Validate a Godot Web export directory and write/verify build-info.json (stdlib only).

build-info.json is the identity card of an export: it ties the bytes to the commit, the workflow run, the pinned
engine and the file hashes. The pre-deploy smoke test, the deploy job and the post-deploy smoke test all re-check it,
so "what was tested" and "what is live" are provably "what was built from this commit".
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import re
from pathlib import Path
from typing import Dict, List, Mapping, NamedTuple, Optional

from ci_common import is_selftest_name

SCHEMA_VERSION = 1
KINDS = ("game", "selftest")
REQUIRED_FILES = ("index.html", "index.js", "index.wasm", "index.pck")
MIN_SIZES = {"index.html": 500, "index.js": 10_000, "index.wasm": 1_000_000, "index.pck": 64}
WASM_MAGIC, PCK_MAGIC = b"\x00asm", b"GDPC"
TOTAL_WARN, TOTAL_ERROR, FILE_WARN = 250 * 2**20, 900 * 2**20, 90 * 2**20  # GitHub Pages sites are limited to 1 GB
THREADS_RE = re.compile(r"const GODOT_THREADS_ENABLED = (true|false);")
CONFIG_RE = re.compile(r"const GODOT_CONFIG = (\{.*\});")
SHA40 = re.compile(r"[0-9a-f]{40}")
BUILD_INFO_KEYS = ("schema_version", "kind", "commit_sha", "head_sha", "ref", "event", "repository", "workflow", "run_id",
                   "run_number", "run_attempt", "built_at", "godot_version", "godot_version_string", "export_mode",
                   "templates", "renderer", "thread_support", "project_dir", "project_name", "export_preset", "files")


class Finding(NamedTuple):
    level: str  # error | warning
    code: str
    message: str


def require_sha40(value: Optional[str], what: str) -> str:
    """An empty or malformed commit id is a usage error. It must never silently turn an identity check into a no-op
    (for example when a workflow output was renamed and expands to an empty string)."""
    if value is None or not SHA40.fullmatch(value):
        raise ValueError(f"{what} must be a 40-character lowercase hex commit SHA, got {value!r}")
    return value


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def export_files(d: Path) -> Dict[str, Path]:
    return {p.relative_to(d).as_posix(): p for p in sorted(d.rglob("*")) if p.is_file() and p.name != "build-info.json"}


def check_export_dir(d: Path) -> List[Finding]:
    """Structural checks of the exported files (independent of build-info.json)."""
    out: List[Finding] = []
    if not d.is_dir():
        return [Finding("error", "EXPORT001", f"export directory {d} does not exist")]
    for p in d.rglob("*"):
        if p.is_symlink():
            out.append(Finding("error", "EXPORT008", f"{p.relative_to(d)} is a symlink; exports must be plain files"))
    files = export_files(d)
    for name in REQUIRED_FILES:
        if name not in files:
            out.append(Finding("error", "EXPORT001", f"required export file {name} is missing"))
        elif files[name].stat().st_size < MIN_SIZES[name]:
            out.append(Finding("error", "EXPORT002", f"{name} is only {files[name].stat().st_size} bytes (expected at least {MIN_SIZES[name]})"))
    if "index.wasm" in files and files["index.wasm"].read_bytes()[:4] != WASM_MAGIC:
        out.append(Finding("error", "EXPORT003", "index.wasm does not start with the WebAssembly magic bytes"))
    if "index.pck" in files and files["index.pck"].read_bytes()[:4] != PCK_MAGIC:
        out.append(Finding("error", "EXPORT004", "index.pck does not start with the Godot pack magic (GDPC)"))
    if "index.html" in files:
        html = files["index.html"].read_text(encoding="utf-8", errors="replace")
        m = THREADS_RE.search(html)
        if m is None:
            out.append(Finding("warning", "EXPORT005", "index.html has no GODOT_THREADS_ENABLED constant (custom HTML shell?); the single-thread check relies on the engine banner in the smoke test"))
        elif m.group(1) != "false":
            out.append(Finding("error", "EXPORT005", "index.html says GODOT_THREADS_ENABLED = true: this is a THREADED export, which GitHub Pages cannot serve (no COOP/COEP headers)"))
        c = CONFIG_RE.search(html)
        if c:
            try:
                sizes = json.loads(c.group(1)).get("fileSizes", {})
            except ValueError:
                sizes = {}
                out.append(Finding("error", "EXPORT006", "GODOT_CONFIG in index.html is not valid JSON"))
            for name, size in sizes.items():
                if name in files and files[name].stat().st_size != size:
                    out.append(Finding("error", "EXPORT006", f"GODOT_CONFIG says {name} is {size} bytes but the file is {files[name].stat().st_size} bytes (corrupt or mixed export)"))
    total = sum(p.stat().st_size for p in files.values())
    if total > TOTAL_ERROR:
        out.append(Finding("error", "EXPORT007", f"export is {total // 2**20} MiB; GitHub Pages sites are limited to 1 GB"))
    elif total > TOTAL_WARN:
        out.append(Finding("warning", "EXPORT007", f"export is {total // 2**20} MiB (warning above {TOTAL_WARN // 2**20} MiB)"))
    for name, p in files.items():
        if p.stat().st_size > FILE_WARN:
            out.append(Finding("warning", "EXPORT007", f"{name} is {p.stat().st_size // 2**20} MiB (single files above {FILE_WARN // 2**20} MiB are risky)"))
    if any(n.endswith(".service.worker.js") for n in files):
        out.append(Finding("warning", "EXPORT010", "PWA service worker files are present; the smoke test blocks service workers"))
    return out


SPRITE_ROOT = "assets/characters"
SPRITE_SKIP_DIRS = ("references", "source")  # mirrors exclude_filter in export_presets.cfg


def expected_pck_entries(project: Path) -> Dict[str, List[str]]:
    """Sprite files that the export preset must ship: every *.manifest.json under assets/characters (include_filter
    "*.json") and the Godot import record "<name>.png.import" of every PNG (the PCK stores that, not the raw PNG)."""
    root = project / SPRITE_ROOT
    found: Dict[str, List[str]] = {"manifests": [], "pngs": []}
    if not root.is_dir():
        return found
    for p in sorted(root.rglob("*")):
        rel = p.relative_to(project)
        if not p.is_file() or any(part in SPRITE_SKIP_DIRS for part in rel.parts[2:-1]):
            continue
        if p.name.endswith(".manifest.json"):
            found["manifests"].append(rel.as_posix())
        elif p.suffix.lower() == ".png":
            found["pngs"].append(rel.as_posix() + ".import")
    return found


def check_pck_contents(d: Path, project: Path) -> "tuple[List[Finding], List[str]]":
    """Byte-scan index.pck for the entries the project says must ship. Returns (findings, notes); notes always state
    exactly what was asserted, so a pass is never silent."""
    pck = d / "index.pck"
    if not pck.is_file():
        return [Finding("error", "EXPORT011", "index.pck is missing; cannot check its contents")], []
    data = pck.read_bytes()
    out: List[Finding] = []
    if b"project.binary" not in data:
        out.append(Finding("error", "EXPORT011", "index.pck has no project.binary entry (the project settings were not packed)"))
    expected = expected_pck_entries(project)
    for kind, label in (("manifests", "sprite manifest"), ("pngs", "sprite PNG import record")):
        for name in expected[kind]:
            if name.encode("utf-8") not in data:
                hint = " (check include_filter in export_presets.cfg)" if kind == "manifests" else ""
                out.append(Finding("error", "EXPORT011", f"index.pck does not contain the {label} {name}{hint}"))
    n_m, n_p = len(expected["manifests"]), len(expected["pngs"])
    notes = [f"PCK contents: project.binary present; asserted {n_m} sprite manifest(s) and {n_p} sprite PNG import record(s) in index.pck"
             + (" (no sprites under assets/characters yet, nothing sprite-related to assert)" if n_m == 0 and n_p == 0 else "")]
    return out, notes


def make_build_info(d: Path, *, kind: str, env: Mapping[str, str], godot_version: str, godot_version_string: str,
                    project_dir: str, project_name: str, preset: str = "Web", export_mode: str = "debug") -> Dict[str, object]:
    if kind not in KINDS:
        raise ValueError(f"kind must be one of {KINDS}")
    sha = require_sha40(env.get("GITHUB_SHA", ""), "GITHUB_SHA (set it explicitly when running locally)")
    if kind == "game" and is_selftest_name(project_name):
        raise ValueError(f"project {project_name!r} is a generated self-test fixture; it can never be exported as kind=game")
    return {
        "schema_version": SCHEMA_VERSION, "kind": kind, "commit_sha": sha,
        "head_sha": env.get("PR_HEAD_SHA") or sha, "ref": env.get("GITHUB_REF", ""), "event": env.get("GITHUB_EVENT_NAME", ""),
        "repository": env.get("GITHUB_REPOSITORY", ""), "workflow": env.get("GITHUB_WORKFLOW", ""),
        "run_id": env.get("GITHUB_RUN_ID", ""), "run_number": env.get("GITHUB_RUN_NUMBER", ""), "run_attempt": env.get("GITHUB_RUN_ATTEMPT", ""),
        "built_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "godot_version": f"{godot_version}-stable", "godot_version_string": godot_version_string,
        "export_mode": export_mode, "templates": f"{godot_version}.stable", "renderer": "gl_compatibility", "thread_support": False,
        "project_dir": project_dir, "project_name": project_name, "export_preset": preset,
        "files": {n: {"size": p.stat().st_size, "sha256": sha256_file(p)} for n, p in export_files(d).items()},
    }


def write_build_info(d: Path, **kwargs: object) -> Path:
    info = make_build_info(d, **kwargs)  # type: ignore[arg-type]
    target = d / "build-info.json"
    target.write_text(json.dumps(info, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    return target


def check_build_info(d: Path, *, kind: Optional[str] = None, expect_sha: Optional[str] = None) -> List[Finding]:
    """Verify build-info.json against the directory: schema, kind, commit, and sha256 of every file."""
    path = d / "build-info.json"
    if not path.is_file():
        return [Finding("error", "EXPORT009", "build-info.json is missing")]
    try:
        info = json.loads(path.read_text(encoding="utf-8"))
    except ValueError as e:
        return [Finding("error", "EXPORT009", f"build-info.json is not valid JSON: {e}")]
    out: List[Finding] = []
    for key in BUILD_INFO_KEYS:
        if key not in info:
            out.append(Finding("error", "EXPORT009", f"build-info.json lacks key {key!r}"))
    if info.get("schema_version") != SCHEMA_VERSION:
        out.append(Finding("error", "EXPORT009", f"unsupported build-info schema_version {info.get('schema_version')!r}"))
    if kind and info.get("kind") != kind:
        out.append(Finding("error", "EXPORT009", f"build-info kind is {info.get('kind')!r}, expected {kind!r}" + (" (a self-test export must never be deployed)" if info.get("kind") == "selftest" else "")))
    if kind == "game" and is_selftest_name(info.get("project_name")):
        out.append(Finding("error", "EXPORT009", f"build-info project_name {info.get('project_name')!r} is a generated self-test fixture; it must never be deployed as the game"))
    if expect_sha is not None:
        require_sha40(expect_sha, "the expected commit SHA")  # ValueError = usage error, never a silent skip
        if info.get("commit_sha") != expect_sha:
            out.append(Finding("error", "EXPORT009", f"build-info commit_sha {info.get('commit_sha')!r} is not the commit under test {expect_sha!r}"))
    if info.get("thread_support") is not False or info.get("renderer") != "gl_compatibility":
        out.append(Finding("error", "EXPORT009", "build-info must record thread_support=false and renderer=gl_compatibility"))
    recorded = info.get("files") or {}
    actual = export_files(d)
    for name in sorted(set(recorded) | set(actual)):
        if name not in actual:
            out.append(Finding("error", "EXPORT009", f"{name} is listed in build-info.json but missing from the export"))
        elif name not in recorded:
            out.append(Finding("error", "EXPORT009", f"{name} is in the export but not listed in build-info.json"))
        elif sha256_file(actual[name]) != recorded[name].get("sha256"):
            out.append(Finding("error", "EXPORT009", f"{name} differs from the hash recorded in build-info.json (modified after the build)"))
    return out
