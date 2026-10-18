#!/usr/bin/env python3
"""Shared helpers for the Godot CI scripts (stdlib only, Python >= 3.10).

* GitHub workflow commands (annotations, step summary, outputs) with correct escaping.
* sanitize(): text that comes from the project, Godot logs or the browser is UNTRUSTED and must never be able to
  inject workflow commands such as ::stop-commands:: or ::error::.
* run_logged(): run a subprocess with a hard timeout and an output cap, merge stderr into stdout, strip ANSI,
  write a log file. The WHOLE output is kept and scanned (no head/tail truncation, so an engine error can never fall
  into a gap); output beyond MAX_LOG_BYTES kills the process and fails closed.
* prepare_owned_dir() / refuse_unsafe_delete(): every recursive delete in the tooling goes through these, so a wrong
  --work-dir or --dest can never wipe a home directory, the checkout or somebody's data.
"""
from __future__ import annotations

import contextlib
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, Mapping, Optional, Sequence

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
_CONTROL_RE = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
SUMMARY_LIMIT_BYTES = 900_000  # GitHub caps a step summary at 1 MiB
MAX_LOG_BYTES = 128 * 1024 * 1024  # a Godot run printing more than this is a runaway; kill it instead of exhausting RAM
OWNER_MARKER = ".shinobi-ci-owned"  # written into every scratch directory this tooling creates; required before it deletes one
REPO_ROOT = Path(__file__).resolve().parents[2]
SELFTEST_PROJECT_NAME = "Pipeline Self-Test (not the game)"  # config/name of every generated self-test fixture
ALLOW_SELFTEST_ENV = "SHINOBI_ALLOW_SELFTEST_PROJECT"  # set to 1 ONLY by selftest.py for its own child processes


def is_selftest_name(name: object) -> bool:
    """True for the config/name of a generated self-test fixture (case-insensitive, whitespace-tolerant)."""
    return "self-test (not the game)" in " ".join(str(name or "").lower().split())


def in_github_actions() -> bool:
    return os.environ.get("GITHUB_ACTIONS") == "true"


def strip_ansi(text: str) -> str:
    return ANSI_RE.sub("", text)


def sanitize(text: str, max_len: int = 500) -> str:
    """Make untrusted text safe to print into a workflow log: drop control chars, defuse a leading '::'."""
    text = _CONTROL_RE.sub("", strip_ansi(str(text))).replace("\r", "")
    text = re.sub(r"(^|\n)(\s*)::", lambda m: f"{m.group(1)}{m.group(2)}:\u200b:", text)
    return text[:max_len]


def escape_data(value: str) -> str:
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(value: str) -> str:
    return escape_data(value).replace(":", "%3A").replace(",", "%2C")


def annotate(level: str, message: str, *, title: str = "", file: str = "", line: Optional[int] = None) -> None:
    """level: error | warning | notice. Prints a workflow command in Actions, a plain line elsewhere."""
    assert level in ("error", "warning", "notice")
    message = sanitize(message, 1500)
    if not in_github_actions():
        prefix = f"{level.upper()}: " + (f"[{title}] " if title else "")
        print(prefix + message.replace("\n", " "), flush=True)
        return
    props = []
    if title:
        props.append(f"title={escape_property(sanitize(title, 120))}")
    if file:
        props.append(f"file={escape_property(file)}")
    if line:
        props.append(f"line={int(line)}")
    head = f"::{level} {','.join(props)}::" if props else f"::{level}::"
    print(head + escape_data(message), flush=True)


@contextlib.contextmanager
def group(title: str) -> Iterator[None]:
    if in_github_actions():
        print(f"::group::{escape_data(sanitize(title, 200))}", flush=True)
    else:
        print(f"--- {title}", flush=True)
    try:
        yield
    finally:
        if in_github_actions():
            print("::endgroup::", flush=True)


def write_summary(markdown: str) -> None:
    """Append Markdown to $GITHUB_STEP_SUMMARY (no-op locally). Truncates instead of failing."""
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    data = (markdown if markdown.endswith("\n") else markdown + "\n").encode("utf-8")
    if len(data) > SUMMARY_LIMIT_BYTES:
        data = data[:SUMMARY_LIMIT_BYTES] + b"\n\n_(summary truncated)_\n"
    with open(path, "ab") as fh:
        fh.write(data)


def _append_kv(env_name: str, name: str, value: str) -> None:
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
        raise ValueError(f"invalid name {name!r}")
    if "\n" in value or "\r" in value:
        raise ValueError(f"{name}: value must be a single line")
    path = os.environ.get(env_name)
    if path:
        with open(path, "a", encoding="utf-8", newline="\n") as fh:
            fh.write(f"{name}={value}\n")


def set_output(name: str, value: str) -> None:
    _append_kv("GITHUB_OUTPUT", name, value)


def set_env(name: str, value: str) -> None:
    _append_kv("GITHUB_ENV", name, value)


@dataclass
class RunResult:
    returncode: int  # -1 when the process was killed on timeout or on output overflow
    text: str  # merged stdout+stderr, ANSI stripped, COMPLETE unless `overflow` is set
    timed_out: bool
    seconds: float
    overflow: bool = False  # more than max_bytes of output: the process was killed; `text` holds only the first max_bytes


def run_logged(cmd: Sequence[str], *, log_path: Optional[Path] = None, timeout: float = 600,
               cwd: Optional[Path] = None, env: Optional[Mapping[str, str]] = None,
               max_bytes: int = MAX_LOG_BYTES) -> RunResult:
    """Run cmd (no shell), merge stderr into stdout, enforce a hard timeout and an output cap, write the cleaned log.

    The output is read by a thread so the child can never block on a full pipe. Nothing is dropped from the middle:
    callers scan the full `text`. If the cap is hit the process is killed and `overflow` is True (callers must fail).
    """
    start = time.monotonic()
    proc = subprocess.Popen(list(cmd), cwd=cwd, env=None if env is None else dict(env),
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    chunks: list = []
    state = {"size": 0, "overflow": False}

    def pump() -> None:
        assert proc.stdout is not None
        while True:
            chunk = proc.stdout.read1(1 << 16)  # type: ignore[attr-defined]
            if not chunk:
                return
            if state["overflow"]:
                continue  # keep draining until the process is gone
            room = max_bytes - state["size"]
            if len(chunk) > room:
                chunks.append(chunk[:room])
                state["size"] = max_bytes
                state["overflow"] = True
                continue
            chunks.append(chunk)
            state["size"] += len(chunk)

    reader = threading.Thread(target=pump, daemon=True)
    reader.start()
    deadline = start + timeout
    timed_out = False
    while True:
        try:
            proc.wait(timeout=0.2)
            break
        except subprocess.TimeoutExpired:
            if state["overflow"] or time.monotonic() >= deadline:
                timed_out = not state["overflow"]
                proc.kill()
                proc.wait()
                break
    reader.join(timeout=30)
    if not reader.is_alive() and proc.stdout is not None:
        proc.stdout.close()  # a surviving grandchild could still hold the pipe; then the daemon reader is simply abandoned
    text = strip_ansi(b"".join(chunks).decode("utf-8", errors="replace")).replace("\r\n", "\n").replace("\r", "\n")
    seconds = time.monotonic() - start
    overflow = bool(state["overflow"])
    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        header = (f"$ {' '.join(cmd)}\n# exit={proc.returncode} timed_out={timed_out} overflow={overflow} "
                  f"seconds={seconds:.1f}\n\n")
        log_path.write_text(header + text, encoding="utf-8", newline="\n")
    return RunResult(-1 if (timed_out or overflow) else proc.returncode, text, timed_out, seconds, overflow)


class UnsafePath(ValueError):
    """A recursive delete was refused because the target could be real data."""


def refuse_unsafe_delete(path: Path) -> Path:
    """Return the resolved path, or raise UnsafePath if recursively deleting it could destroy real data:
    a filesystem root, the home directory, the working directory, the repository checkout, or any ancestor of those."""
    p = Path(path).resolve()
    protected = {Path(p.anchor), Path.home().resolve(), Path.cwd().resolve(), REPO_ROOT}
    if len(p.parts) < 2 or p in protected or any(p in q.parents for q in protected):
        raise UnsafePath(f"refusing to delete {p}: it is a root, home, working or repository directory, or contains one")
    return p


def prepare_owned_dir(path: Path) -> Path:
    """Create an empty scratch directory this tooling owns (marker file inside). An existing non-empty directory is
    wiped only if an earlier run marked it; any other non-empty directory is refused, never deleted."""
    p = refuse_unsafe_delete(path)
    if p.exists():
        if not p.is_dir():
            raise UnsafePath(f"{p} exists and is not a directory")
        if any(p.iterdir()):
            if not (p / OWNER_MARKER).is_file():
                raise UnsafePath(f"{p} is not empty and was not created by this tooling (no {OWNER_MARKER} marker); "
                                 "refusing to delete it. Choose a new or empty directory.")
            shutil.rmtree(p)
    p.mkdir(parents=True, exist_ok=True)
    (p / OWNER_MARKER).write_text("scratch directory created by scripts/ci; safe to delete\n", encoding="utf-8", newline="\n")
    return p


def die(message: str, code: int = 1, *, title: str = "") -> "None":
    annotate("error", message, title=title)
    sys.exit(code)
