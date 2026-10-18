#!/usr/bin/env python3
"""Scan Godot CLI output for problems. Godot exits 0 on many real errors (verified on 4.7.2: a GDScript parse
error during --import, and a parse error during --export-debug, both exit 0), so the log text is authoritative.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Sequence

from ci_common import strip_ansi

# Header lines produced by the engine's error printer ("ERROR: ...", "SCRIPT ERROR: ...", "USER ERROR: ...").
FATAL_RE = re.compile(r"^(?:USER )?(?:SCRIPT )?ERROR: |^handle_crash: Program crashed|^Unknown rendering method|^Invalid renderer/driver combination")
WARNING_RE = re.compile(r"^(?:USER )?(?:SCRIPT )?WARNING: ")
# Indented continuation lines belong to the preceding header ("   at: ...", "   GDScript backtrace ...", "       [0] ...").
CONTINUATION_RE = re.compile(r"^\s+\S")


@dataclass
class ScanResult:
    errors: List[str] = field(default_factory=list)  # one entry per fatal header line
    warnings: List[str] = field(default_factory=list)
    allowlisted: int = 0

    @property
    def ok(self) -> bool:
        return not self.errors


def load_allowlist(path: Path) -> List[re.Pattern[str]]:
    """One regular expression per line; '#' starts a comment. Each entry needs a justification comment above it."""
    patterns: List[re.Pattern[str]] = []
    if path.is_file():
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if line and not line.startswith("#"):
                patterns.append(re.compile(line))
    return patterns


def scan(text: str, allowlist: Sequence[re.Pattern[str]] = ()) -> ScanResult:
    result = ScanResult()
    skipping = False  # inside the continuation block of an allowlisted header
    for raw in strip_ansi(text).replace("\r", "").split("\n"):
        line = raw.rstrip()
        if not line:
            skipping = False
            continue
        is_fatal = bool(FATAL_RE.match(line))
        is_warning = bool(WARNING_RE.match(line))
        if is_fatal or is_warning:
            if any(p.search(line) for p in allowlist):
                result.allowlisted += 1
                skipping = True
                continue
            skipping = False
            (result.errors if is_fatal else result.warnings).append(line)
        elif skipping and CONTINUATION_RE.match(line):
            continue
        else:
            skipping = False
    return result
